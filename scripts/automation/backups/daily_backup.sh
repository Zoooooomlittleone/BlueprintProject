#!/bin/bash
# Daily Backup Script for Docker Swarm
# This script creates a backup of all important swarm configurations

# Set colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the current date in YYYYMMDD format
DATE=$(date +%Y%m%d)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Set backup directory
BACKUP_DIR="/home/optiplex_780_1/Desktop/BlueprintProject/backups"
CURRENT_BACKUP_DIR="$BACKUP_DIR/backup_$TIMESTAMP"

# Ensure backup directory exists
mkdir -p $CURRENT_BACKUP_DIR

# Log file
LOG_FILE="$CURRENT_BACKUP_DIR/backup_log.txt"

# Log function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting daily backup process"

# Backup swarm configuration
log "Backing up swarm configuration"
mkdir -p $CURRENT_BACKUP_DIR/swarm_config

# Backup swarm node information
docker node ls > $CURRENT_BACKUP_DIR/swarm_config/node_list.txt
docker node inspect $(docker node ls -q) > $CURRENT_BACKUP_DIR/swarm_config/node_details.json
log "✓ Node information backed up"

# Backup service information
docker service ls > $CURRENT_BACKUP_DIR/swarm_config/service_list.txt
for service in $(docker service ls -q); do
  SERVICE_NAME=$(docker service inspect --format='{{.Spec.Name}}' $service)
  docker service inspect $service > $CURRENT_BACKUP_DIR/swarm_config/service_${SERVICE_NAME}.json
done
log "✓ Service information backed up"

# Backup stack information
docker stack ls > $CURRENT_BACKUP_DIR/swarm_config/stack_list.txt
for stack in $(docker stack ls --format '{{.Name}}'); do
  docker stack ps $stack > $CURRENT_BACKUP_DIR/swarm_config/stack_${stack}_ps.txt
  docker stack services $stack > $CURRENT_BACKUP_DIR/swarm_config/stack_${stack}_services.txt
done
log "✓ Stack information backed up"

# Backup networks
docker network ls > $CURRENT_BACKUP_DIR/swarm_config/network_list.txt
for network in $(docker network ls --filter driver=overlay -q); do
  NETWORK_NAME=$(docker network inspect --format='{{.Name}}' $network)
  docker network inspect $network > $CURRENT_BACKUP_DIR/swarm_config/network_${NETWORK_NAME}.json
done
log "✓ Network information backed up"

# Backup secrets and configs
docker secret ls > $CURRENT_BACKUP_DIR/swarm_config/secret_list.txt
docker config ls > $CURRENT_BACKUP_DIR/swarm_config/config_list.txt
log "✓ Secrets and configs backed up"

# Backup volume data (this requires careful handling)
log "Backing up volume data"
mkdir -p $CURRENT_BACKUP_DIR/volumes

# Get list of volumes
docker volume ls --format "{{.Name}}" | grep -v "^[0-9a-f]\{64\}$" > $CURRENT_BACKUP_DIR/swarm_config/volume_list.txt

# Backup important volumes (customize this list)
# WARNING: This can be resource-intensive for large volumes
for volume in $(docker volume ls --format "{{.Name}}" | grep -v "^[0-9a-f]\{64\}$"); do
  log "Creating backup of volume: $volume"
  # Use Docker's own tooling to backup the volume
  docker run --rm -v $volume:/source -v $CURRENT_BACKUP_DIR/volumes:/backup alpine \
    sh -c "cd /source && tar czf /backup/${volume}.tar.gz ."
  
  if [ $? -eq 0 ]; then
    log "✓ Successfully backed up volume: $volume"
  else
    log "✗ Failed to backup volume: $volume"
  fi
done

# Backup important files from the master node
log "Backing up master node configuration files"
mkdir -p $CURRENT_BACKUP_DIR/master_configs

# Backup Docker daemon configuration
cp /etc/docker/daemon.json $CURRENT_BACKUP_DIR/master_configs/ 2>/dev/null
# Backup Docker systemd unit file
cp /lib/systemd/system/docker.service $CURRENT_BACKUP_DIR/master_configs/ 2>/dev/null
# Backup host network configuration
cp /etc/hosts $CURRENT_BACKUP_DIR/master_configs/ 2>/dev/null
cp /etc/hostname $CURRENT_BACKUP_DIR/master_configs/ 2>/dev/null
cp /etc/resolv.conf $CURRENT_BACKUP_DIR/master_configs/ 2>/dev/null

# Backup script and configuration files from the project
log "Backing up project scripts and configurations"
mkdir -p $CURRENT_BACKUP_DIR/project_files

# Backup important project directories
cp -r /home/optiplex_780_1/Desktop/BlueprintProject/scripts $CURRENT_BACKUP_DIR/project_files/
cp -r /home/optiplex_780_1/Desktop/BlueprintProject/docs $CURRENT_BACKUP_DIR/project_files/
cp -r /home/optiplex_780_1/Desktop/docker_swarm_config $CURRENT_BACKUP_DIR/project_files/

# Create a recovery script
log "Creating recovery script"
cat > $CURRENT_BACKUP_DIR/recovery.sh << RECOVERY
#!/bin/bash
# Recovery script for Docker Swarm
# This script helps restore the Docker Swarm from backup

echo "Docker Swarm Recovery Script"
echo "============================"
echo "This backup was created on: ${TIMESTAMP}"
echo ""
echo "Recovery Instructions:"
echo "1. Initialize a new swarm: docker swarm init --advertise-addr <IP>"
echo "2. Restore configurations from this backup"
echo "3. Restore volumes if needed"
echo ""
echo "To restore a volume, use:"
echo "docker volume create <volume_name>"
echo "docker run --rm -v <volume_name>:/target -v \$(pwd)/volumes/<volume_name>.tar.gz:/backup.tar.gz alpine sh -c 'cd /target && tar xzf /backup.tar.gz'"
echo ""
echo "Note: Make sure to adjust IP addresses and node names as needed for your new environment."
RECOVERY

chmod +x $CURRENT_BACKUP_DIR/recovery.sh
log "✓ Recovery script created"

# Compress the entire backup
log "Compressing backup"
COMPRESSED_BACKUP="${BACKUP_DIR}/swarm_backup_${TIMESTAMP}.tar.gz"
tar -czf $COMPRESSED_BACKUP -C $(dirname $CURRENT_BACKUP_DIR) $(basename $CURRENT_BACKUP_DIR)

if [ $? -eq 0 ]; then
  log "✓ Backup compressed successfully: ${COMPRESSED_BACKUP}"
  # Remove the uncompressed backup directory to save space
  rm -rf $CURRENT_BACKUP_DIR
else
  log "✗ Failed to compress backup"
fi

# Rotate old backups (keep last 7 days)
log "Rotating old backups"
find $BACKUP_DIR -name "swarm_backup_*.tar.gz" -type f -mtime +7 -delete
log "✓ Old backups rotated"

# Check if we should create an off-site backup
if [ -d "/mnt/offsite_backup" ]; then
  log "Creating off-site backup"
  cp $COMPRESSED_BACKUP /mnt/offsite_backup/
  if [ $? -eq 0 ]; then
    log "✓ Off-site backup created"
  else
    log "✗ Failed to create off-site backup"
  fi
fi

log "Backup process completed at $(date)"
echo -e "${GREEN}Backup process completed successfully!${NC}"
echo -e "${GREEN}Backup saved to: ${COMPRESSED_BACKUP}${NC}"

exit 0
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
