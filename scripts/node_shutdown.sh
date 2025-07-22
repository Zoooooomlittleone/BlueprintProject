#!/bin/bash

# Node Shutdown Script for Docker Swarm Cluster
# This script runs when master node shuts down and ensures all worker nodes shut down gracefully

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="/var/log/node_shutdown.log"

# Create log file if it doesn't exist
if [ ! -f "$LOG_FILE" ]; then
    sudo touch "$LOG_FILE"
    sudo chmod 644 "$LOG_FILE"
fi

# Log function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE"
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}This script must be run as root (use sudo)${NC}"
  exit 1
fi

log_message "Starting node shutdown sequence for Docker Swarm cluster"

# Ensure Docker service is running
if ! systemctl is-active --quiet docker; then
    log_message "${RED}Docker service is not running. Cannot proceed with graceful shutdown.${NC}"
    exit 1
fi

# Define node configurations
declare -A NODE_CONFIGS
NODE_CONFIGS["optiplex70101"]="192.168.0.202 server"
NODE_CONFIGS["optiplex70102"]="192.168.0.203 server"
NODE_CONFIGS["docker-desktop"]="192.168.0.205 laptop"
NODE_CONFIGS["hp-laptop"]="192.168.0.204 laptop"
NODE_CONFIGS["samsung-a50"]="192.168.0.210 mobile"
NODE_CONFIGS["lenovo-laptop"]="192.168.0.205 laptop"

# Check if we're in a swarm
SWARM_STATUS=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)
if [ "$SWARM_STATUS" != "active" ]; then
    log_message "${RED}Not in an active swarm. Cannot proceed with graceful shutdown.${NC}"
    exit 1
fi

# Check if we're a manager
NODE_ROLE=$(docker info --format '{{.Swarm.ControlAvailable}}')
if [ "$NODE_ROLE" != "true" ]; then
    log_message "${RED}This node is not a swarm manager. Cannot proceed with graceful shutdown.${NC}"
    exit 1
fi

# Backup swarm configuration
log_message "Backing up swarm configuration..."
BACKUP_DIR="/home/optiplex_780_1/Desktop/Backups/swarm_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Save service list
docker service ls --format "{{.Name}}" > "$BACKUP_DIR/service_list.txt"
log_message "✓ Service list backed up"

# Save service details
for SERVICE in $(docker service ls --format "{{.Name}}"); do
    docker service inspect "$SERVICE" > "$BACKUP_DIR/${SERVICE}_config.json"
done
log_message "✓ Service configurations backed up"

# Save node list
docker node ls --format "{{.ID}} {{.Hostname}} {{.Status.State}}" > "$BACKUP_DIR/node_list.txt"
log_message "✓ Node list backed up"

# Scale down services gracefully
log_message "Scaling down services gracefully..."
for SERVICE in $(docker service ls --format "{{.Name}}"); do
    log_message "Scaling down $SERVICE..."
    docker service scale "$SERVICE=0"
done
log_message "✓ All services scaled down"

# Wait for containers to stop
log_message "Waiting for containers to stop..."
TIMEOUT=30
for i in $(seq 1 $TIMEOUT); do
    RUNNING_CONTAINERS=$(docker ps --format "{{.Names}}" | grep -v "visualizer" | wc -l)
    if [ "$RUNNING_CONTAINERS" -eq "0" ]; then
        log_message "✓ All service containers stopped"
        break
    fi
    if [ "$i" -eq "$TIMEOUT" ]; then
        log_message "${YELLOW}Timeout waiting for containers to stop. Proceeding anyway.${NC}"
    fi
    sleep 1
done

# Shut down worker nodes
log_message "Initiating shutdown of worker nodes..."

# First, process Linux server nodes
for NODE_NAME in "optiplex70101" "optiplex70102"; do
    NODE_INFO=(${NODE_CONFIGS[$NODE_NAME]})
    NODE_IP=${NODE_INFO[0]}
    
    if ping -c 1 -W 2 "$NODE_IP" &> /dev/null; then
        log_message "Shutting down $NODE_NAME ($NODE_IP)..."
        ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$NODE_IP" "sudo shutdown -h now" || log_message "${RED}Failed to shut down $NODE_NAME${NC}"
    else
        log_message "${YELLOW}$NODE_NAME is not reachable, skipping shutdown${NC}"
    fi
done

# Handle special case for Lenovo laptop
if ping -c 1 -W 2 "192.168.0.205" &> /dev/null; then
    log_message "${YELLOW}Lenovo laptop (docker-desktop) detected at 192.168.0.205${NC}"
    log_message "Attempting to shut down Lenovo laptop..."
    
    # Try connecting via SSH to Windows PowerShell
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 Administrator@192.168.0.205 "powershell -Command \"Stop-Service docker; Start-Sleep -s 5; shutdown /s /t 30 /f /c \\\"Docker Swarm cluster shutdown\\\"\"" 2>/dev/null; then
        log_message "${GREEN}✓ Lenovo laptop shutdown command sent successfully${NC}"
    else
        log_message "${RED}Failed to send shutdown command to Lenovo laptop${NC}"
        
        # Try alternative user
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 user@192.168.0.205 "powershell -Command \"Stop-Service docker; Start-Sleep -s 5; shutdown /s /t 30 /f /c \\\"Docker Swarm cluster shutdown\\\"\"" 2>/dev/null; then
            log_message "${GREEN}✓ Lenovo laptop shutdown command sent successfully via alternate user${NC}"
        else
            log_message "${RED}Failed to send shutdown command to Lenovo laptop${NC}"
            log_message "${YELLOW}The Lenovo laptop must be shut down manually${NC}"
            log_message "${YELLOW}Please ensure the Lenovo laptop is properly shut down to prevent data loss${NC}"
        fi
    fi
fi

# Handle Samsung A50 mobile node shutdown
if ping -c 1 -W 2 "192.168.0.210" &> /dev/null; then
    log_message "Samsung A50 detected at 192.168.0.210"
    log_message "Ensuring Docker services are stopped on Samsung A50..."
    
    # The SSH user might be different depending on Termux setup
    for USER_PREFIX in "u0_a" "shell" "root"; do
        USER_ID="${USER_PREFIX}$(id -u 2>/dev/null || echo "10")"
        
        if ssh -p 8022 -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$USER_ID@192.168.0.210" "command -v docker" &>/dev/null; then
            log_message "${GREEN}✓ Connected to Samsung A50 with user $USER_ID${NC}"
            ssh -p 8022 -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$USER_ID@192.168.0.210" \
              "pkill -f docker; docker-compose down 2>/dev/null; docker swarm leave 2>/dev/null" \
              || log_message "${YELLOW}Could not stop Docker on Samsung A50${NC}"
            break
        fi
    done
    
    log_message "Mobile devices generally manage their own power state"
    log_message "${YELLOW}Please ensure the Samsung A50 application is properly closed${NC}"
fi

# Handle HP laptop shutdown
if ping -c 1 -W 2 "192.168.0.204" &> /dev/null; then
    log_message "${YELLOW}HP laptop detected at 192.168.0.204${NC}"
    log_message "Attempting to shut down HP laptop..."
    # Try connecting via SSH to Windows PowerShell
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 Administrator@192.168.0.204 "powershell -Command \"Stop-Service docker; Start-Sleep -s 5; shutdown /s /t 30 /f /c \\\"Docker Swarm cluster shutdown\\\"\"" 2>/dev/null; then
        log_message "${GREEN}✓ HP laptop shutdown command sent successfully${NC}"
    else
        log_message "${RED}Failed to send shutdown command to HP laptop${NC}"
        log_message "${YELLOW}The HP laptop must be shut down manually${NC}"
        log_message "${YELLOW}Please ensure the HP laptop is properly shut down to prevent data loss${NC}"
    fi
fi

# Final log message
log_message "All worker nodes have been notified for shutdown"
log_message "✓ The master node will now proceed with its own shutdown"
log_message "======================= END OF SHUTDOWN SEQUENCE ======================="

# The system shutdown process will continue after this script exits
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
