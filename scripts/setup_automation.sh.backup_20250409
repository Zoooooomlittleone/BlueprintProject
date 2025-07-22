#!/bin/bash
# Docker Swarm Automation Setup Script
# This script sets up:
# 1. Automated health checks
# 2. Load balancing configuration
# 3. Automated backups
# 4. Cron jobs for scheduled tasks

# Set colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print header
echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}        DOCKER SWARM AUTOMATION SETUP        ${NC}"
echo -e "${BLUE}=====================================================${NC}"

# Check if running as root (needed for cron and service access)
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}This script must be run as root (use sudo)${NC}"
  exit 1
fi

# Verify we're on the master node
HOSTNAME=$(hostname)
if [ "$HOSTNAME" != "optiplex_780_1" ] && [ "$HOSTNAME" != "master" ]; then
  echo -e "${RED}This script must be run on the master node (optiplex_780_1)${NC}"
  exit 1
fi

# Check if we're in an active swarm
SWARM_STATUS=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)
if [ "$SWARM_STATUS" != "active" ]; then
  echo -e "${RED}Not in an active swarm. Please initialize swarm first.${NC}"
  exit 1
fi

# Check if this node is a manager
NODE_ROLE=$(docker info --format '{{.Swarm.ControlAvailable}}')
if [ "$NODE_ROLE" != "true" ]; then
  echo -e "${RED}This node is not a swarm manager. Cannot continue.${NC}"
  exit 1
fi

# Create necessary directories
echo -e "${YELLOW}Creating necessary directories...${NC}"
AUTOMATION_DIR="/home/optiplex_780_1/Desktop/BlueprintProject/scripts/automation"
BACKUP_DIR="/home/optiplex_780_1/Desktop/BlueprintProject/backups"
LOG_DIR="/home/optiplex_780_1/Desktop/BlueprintProject/logs"

mkdir -p $AUTOMATION_DIR
mkdir -p $BACKUP_DIR
mkdir -p $LOG_DIR
mkdir -p $AUTOMATION_DIR/healthchecks
mkdir -p $AUTOMATION_DIR/loadbalancing
mkdir -p $AUTOMATION_DIR/backups

echo -e "${GREEN}✓ Directories created${NC}"

# Copy scripts to appropriate locations
echo -e "${YELLOW}Configuring health check scripts...${NC}"
chmod +x $AUTOMATION_DIR/healthchecks/check_swarm_health.sh
chmod +x $AUTOMATION_DIR/healthchecks/heal_swarm.sh

echo -e "${YELLOW}Configuring load balancing scripts...${NC}"
chmod +x $AUTOMATION_DIR/loadbalancing/setup_load_balancer.sh
chmod +x $AUTOMATION_DIR/loadbalancing/setup_monitoring.sh

echo -e "${YELLOW}Configuring backup scripts...${NC}"
chmod +x $AUTOMATION_DIR/backups/daily_backup.sh

# Save swarm join token for recovery
echo -e "${YELLOW}Saving swarm join token for recovery...${NC}"
docker swarm join-token worker -q > /home/optiplex_780_1/Desktop/BlueprintProject/swarm_token.txt
chmod 600 /home/optiplex_780_1/Desktop/BlueprintProject/swarm_token.txt

echo -e "${GREEN}✓ All scripts configured${NC}"

# Set up cron jobs for automation
echo -e "${YELLOW}Setting up cron jobs for automation...${NC}"

# Create temporary crontab file
TEMP_CRONTAB=$(mktemp)

# Add header to the crontab file
cat > $TEMP_CRONTAB << EOF
# Docker Swarm Automation Cron Jobs
# These jobs handle health checks, self-healing, and backups for the Docker Swarm cluster

# Health checks - Run every 15 minutes
*/15 * * * * /home/optiplex_780_1/Desktop/BlueprintProject/scripts/automation/healthchecks/check_swarm_health.sh > /home/optiplex_780_1/Desktop/BlueprintProject/logs/health_check_cron.log 2>&1

# Self-healing - Run hourly
0 * * * * /home/optiplex_780_1/Desktop/BlueprintProject/scripts/automation/healthchecks/heal_swarm.sh > /home/optiplex_780_1/Desktop/BlueprintProject/logs/healing_cron.log 2>&1

# Daily backup - Run at 2:00 AM
0 2 * * * /home/optiplex_780_1/Desktop/BlueprintProject/scripts/automation/backups/daily_backup.sh > /home/optiplex_780_1/Desktop/BlueprintProject/logs/backup_cron.log 2>&1

# Log rotation - Run weekly on Sunday at 3:00 AM
0 3 * * 0 find /home/optiplex_780_1/Desktop/BlueprintProject/logs -name "*.log" -type f -mtime +14 -delete

# Monitor script execution - Check once per day
0 6 * * * ps aux | grep -E "check_swarm_health|heal_swarm|daily_backup" | grep -v grep > /home/optiplex_780_1/Desktop/BlueprintProject/logs/script_status.log 2>&1
EOF

# Install the new crontab
crontab $TEMP_CRONTAB

# Remove the temporary file
rm $TEMP_CRONTAB

echo -e "${GREEN}✓ Cron jobs configured${NC}"

# Setup load balancer and monitoring
echo -e "${YELLOW}Do you want to set up load balancing now? (y/n)${NC}"
read -r setup_lb

if [[ "$setup_lb" =~ ^[Yy]$ ]]; then
  echo -e "${YELLOW}Setting up load balancing...${NC}"
  $AUTOMATION_DIR/loadbalancing/setup_load_balancer.sh
  echo -e "${GREEN}✓ Load balancing setup complete${NC}"
fi

echo -e "${YELLOW}Do you want to set up monitoring now? (y/n)${NC}"
read -r setup_monitoring

if [[ "$setup_monitoring" =~ ^[Yy]$ ]]; then
  echo -e "${YELLOW}Setting up monitoring...${NC}"
  $AUTOMATION_DIR/loadbalancing/setup_monitoring.sh
  echo -e "${GREEN}✓ Monitoring setup complete${NC}"
fi

# Create a README file with usage instructions
echo -e "${YELLOW}Creating documentation...${NC}"
cat > /home/optiplex_780_1/Desktop/BlueprintProject/scripts/automation/README.md << 'EOF'
# Docker Swarm Automation System

This directory contains scripts and configurations for automating various aspects of our Docker Swarm cluster.

## Health Checks

Health check scripts run automatically to monitor the state of the Docker Swarm cluster:

- **check_swarm_health.sh**: Runs every 15 minutes to verify nodes, services, and containers are healthy
- **heal_swarm.sh**: Runs hourly to fix common issues (unhealthy containers, reduced replicas, etc.)

## Load Balancing

The load balancing system uses Traefik:

- **setup_load_balancer.sh**: Deploys Traefik as a load balancer for the swarm
- **setup_monitoring.sh**: Deploys Prometheus and Grafana for monitoring

## Backups

Automated backups ensure the system can be recovered in case of failure:

- **daily_backup.sh**: Runs daily at 2:00 AM to create backups of all important configurations and volumes

## Accessing Services

- **Traefik Dashboard**: http://traefik.local:8000 or http://localhost:8000
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (default credentials: admin/admin)

## Manual Operations

To manually run scripts:

```bash
# Health check
sudo /home/optiplex_780_1/Desktop/BlueprintProject/scripts/automation/healthchecks/check_swarm_health.sh

# Self-healing
sudo /home/optiplex_780_1/Desktop/BlueprintProject/scripts/automation/healthchecks/heal_swarm.sh

# Manual backup
sudo /home/optiplex_780_1/Desktop/BlueprintProject/scripts/automation/backups/daily_backup.sh
```

## Logs

Logs are stored in `/home/optiplex_780_1/Desktop/BlueprintProject/logs/`:

- Health check logs: `swarm_health_YYYYMMDD.log`
- Healing logs: `swarm_healing_YYYYMMDD.log`
- Alert logs: `swarm_alerts.log`
- Backup logs are included in the backup archives

## Recovery

To recover the swarm in case of master node failure:

1. Restore the master node
2. Install Docker if needed
3. Initialize a new swarm: `docker swarm init --advertise-addr 192.168.0.200`
4. Extract the latest backup: `tar -xzf /path/to/swarm_backup_TIMESTAMP.tar.gz`
5. Follow the instructions in the recovered `recovery.sh` script
EOF

# Create a desktop shortcut
echo -e "${YELLOW}Creating desktop shortcut...${NC}"
cat > "/home/optiplex_780_1/Desktop/Automation_Setup.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Swarm Automation Setup
Comment=Configure Docker Swarm automation
Exec=bash -c 'cd /home/optiplex_780_1/Desktop/BlueprintProject/scripts && sudo ./setup_automation.sh; read -p "Press Enter to close..."'
Icon=utilities-terminal
Terminal=true
StartupNotify=true
EOF

chmod +x "/home/optiplex_780_1/Desktop/Automation_Setup.desktop"

# Update the cluster blueprint with automation information
echo -e "${YELLOW}Updating cluster blueprint documentation...${NC}"
cat >> /home/optiplex_780_1/Desktop/BlueprintProject/docs/cluster_blueprint.md << 'EOF'

## 14. AUTOMATION SYSTEM

### Health Checks
The cluster includes an automated health monitoring system that performs:
- Regular health checks every 15 minutes
- Self-healing actions every hour
- Detailed logging of all checks and actions

### Load Balancing
Traefik is deployed as the cluster load balancer, providing:
- Dynamic service discovery
- Automatic SSL termination capability
- Web UI for monitoring traffic
- Integration with Docker Swarm for automatic service routing

### Monitoring
The monitoring stack includes:
- Prometheus for metrics collection
- Grafana for visualization
- Node exporter for hardware-level metrics
- cAdvisor for container-level metrics

### Backup System
Automated backup system includes:
- Daily backups of all swarm configurations at 2:00 AM
- Volume data backups for persistent storage
- 7-day backup rotation
- Recovery scripts included with each backup
EOF

echo -e "${GREEN}✓ Documentation updated${NC}"

# Create a master health check script for manual running
echo -e "${YELLOW}Creating master health check script...${NC}"
cat > /home/optiplex_780_1/Desktop/BlueprintProject/scripts/check_cluster_health.sh << 'EOF'
#!/bin/bash
# Master health check script for Docker Swarm
# This script runs a health check and opens the logs in a text editor

# Set colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}        DOCKER SWARM HEALTH CHECK        ${NC}"
echo -e "${BLUE}=====================================================${NC}"

# Run the health check
echo -e "${YELLOW}Running health check...${NC}"
/home/optiplex_780_1/Desktop/BlueprintProject/scripts/automation/healthchecks/check_swarm_health.sh

# Get the latest log file
LATEST_LOG=$(ls -t /home/optiplex_780_1/Desktop/BlueprintProject/logs/swarm_health_*.log | head -1)

if [ -f "$LATEST_LOG" ]; then
  echo -e "${GREEN}Health check complete. Opening log file...${NC}"
  # Open the log file in a text editor (adjust if needed)
  if command -v xdg-open > /dev/null; then
    xdg-open "$LATEST_LOG"
  else
    # Fallback to basic display
    echo -e "${YELLOW}Log file contents:${NC}"
    cat "$LATEST_LOG"
  fi
else
  echo -e "${RED}No log file found. Health check may have failed.${NC}"
fi

echo -e "${BLUE}=====================================================${NC}"
EOF

chmod +x /home/optiplex_780_1/Desktop/BlueprintProject/scripts/check_cluster_health.sh

# Create a shortcut for the health check
cat > "/home/optiplex_780_1/Desktop/Check_Cluster_Health.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Check Cluster Health
Comment=Run health check on Docker Swarm cluster
Exec=bash -c 'cd /home/optiplex_780_1/Desktop/BlueprintProject/scripts && ./check_cluster_health.sh; read -p "Press Enter to close..."'
Icon=utilities-system-monitor
Terminal=true
StartupNotify=true
EOF

chmod +x "/home/optiplex_780_1/Desktop/Check_Cluster_Health.desktop"

# Make everything executable
echo -e "${YELLOW}Making all scripts executable...${NC}"
chmod +x /home/optiplex_780_1/Desktop/BlueprintProject/scripts/*.sh
find /home/optiplex_780_1/Desktop/BlueprintProject/scripts -name "*.sh" -exec chmod +x {} \;

echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}        DOCKER SWARM AUTOMATION SETUP COMPLETE        ${NC}"
echo -e "${BLUE}=====================================================${NC}"
echo
echo -e "${GREEN}The following automation has been set up:${NC}"
echo -e "  - ${YELLOW}Health checks${NC}: Running every 15 minutes"
echo -e "  - ${YELLOW}Self-healing${NC}: Running hourly"
echo -e "  - ${YELLOW}Backups${NC}: Running daily at 2:00 AM"
echo -e "  - ${YELLOW}Log rotation${NC}: Running weekly"
echo
echo -e "${GREEN}Desktop shortcuts created:${NC}"
echo -e "  - ${YELLOW}Automation Setup${NC}: Run this script again"
echo -e "  - ${YELLOW}Check Cluster Health${NC}: Run a manual health check"
echo
echo -e "${GREEN}Logs available at:${NC}"
echo -e "  ${YELLOW}/home/optiplex_780_1/Desktop/BlueprintProject/logs/${NC}"
echo
echo -e "${GREEN}Documentation available at:${NC}"
echo -e "  ${YELLOW}/home/optiplex_780_1/Desktop/BlueprintProject/scripts/automation/README.md${NC}"
echo
echo -e "${GREEN}Thank you for setting up Docker Swarm automation!${NC}"
echo -e "${BLUE}=====================================================${NC}"
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
