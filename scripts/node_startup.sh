#!/bin/bash

# Node Startup Script for Docker Swarm Cluster
# This script runs on master node startup and ensures all worker nodes are online

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="/var/log/node_startup.log"

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

log_message "Starting node startup sequence for Docker Swarm cluster"

# Ensure Docker service is running
log_message "Ensuring Docker service is running..."
systemctl is-active --quiet docker || systemctl start docker
systemctl is-enabled --quiet docker || systemctl enable docker
if systemctl is-active --quiet docker; then
    log_message "✓ Docker service is active"
else
    log_message "${RED}✗ Failed to start Docker service${NC}"
    exit 1
fi

# Define node configurations
declare -A NODE_CONFIGS
NODE_CONFIGS["optiplex70101"]="192.168.0.202 server 00:11:22:33:44:55"
NODE_CONFIGS["optiplex70102"]="192.168.0.203 server 00:11:22:33:44:66"
NODE_CONFIGS["cluster-node-205"]="192.168.0.205 laptop NA"
NODE_CONFIGS["hp-laptop"]="192.168.0.204 laptop NA"
NODE_CONFIGS["samsung-a50"]="192.168.0.210 mobile NA"

# Check if master node is already part of a swarm
log_message "Checking swarm status on master node..."
SWARM_STATUS=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)

if [ "$SWARM_STATUS" = "active" ]; then
    # If master node is already in a swarm, check if it's a manager
    NODE_ROLE=$(docker info --format '{{.Swarm.ControlAvailable}}')
    if [ "$NODE_ROLE" = "true" ]; then
        log_message "✓ Master node is active as swarm manager"
    else
        log_message "${YELLOW}Master node is in swarm but not as manager, reinitializing...${NC}"
        docker swarm leave --force
        docker swarm init --advertise-addr 192.168.0.200
        log_message "✓ Swarm reinitialized with master as manager"
    fi
else
    # Initialize a new swarm
    log_message "Initializing new swarm with master as manager..."
    docker swarm init --advertise-addr 192.168.0.200
    log_message "✓ New swarm initialized"
fi

# Get the worker join token
JOIN_TOKEN=$(docker swarm join-token worker -q)
log_message "Worker join token: $JOIN_TOKEN"

# Check if manager node has appropriate label
NODE_LABELS=$(docker node ls --filter "role=manager" --format '{{.Hostname}} {{.Labels}}')
if ! echo "$NODE_LABELS" | grep -q "role=manager"; then
    log_message "Adding role=manager label to master node..."
    MASTER_NODE_ID=$(docker node ls --filter "role=manager" --format '{{.ID}}')
    docker node update --label-add role=manager "$MASTER_NODE_ID"
    log_message "✓ Added role=manager label to master node"
fi

# Wake and connect worker nodes
for NODE_NAME in "${!NODE_CONFIGS[@]}"; do
    NODE_INFO=(${NODE_CONFIGS[$NODE_NAME]})
    NODE_IP=${NODE_INFO[0]}
    NODE_TYPE=${NODE_INFO[1]}
    NODE_MAC=${NODE_INFO[2]}
    
    log_message "Processing node $NODE_NAME ($NODE_IP, type: $NODE_TYPE)..."
    
    # Check if node is reachable
    if ping -c 1 -W 2 "$NODE_IP" &> /dev/null; then
        log_message "✓ Node $NODE_NAME is reachable"
    else
        log_message "${YELLOW}Node $NODE_NAME is not responding to ping${NC}"
        
        # If MAC address is available, try Wake-on-LAN
        if [ "$NODE_MAC" != "NA" ]; then
            log_message "Attempting Wake-on-LAN for $NODE_NAME..."
            wakeonlan "$NODE_MAC" 2>/dev/null || log_message "${YELLOW}wakeonlan command failed, trying etherwake...${NC}"
            etherwake "$NODE_MAC" 2>/dev/null || log_message "${RED}Failed to wake $NODE_NAME${NC}"
            
            # Wait for node to boot
            log_message "Waiting for $NODE_NAME to boot..."
            for i in {1..30}; do
                if ping -c 1 -W 2 "$NODE_IP" &> /dev/null; then
                    log_message "✓ Node $NODE_NAME is now online"
                    break
                fi
                if [ $i -eq 30 ]; then
                    log_message "${RED}✗ Timed out waiting for $NODE_NAME to respond${NC}"
                fi
                sleep 2
            done
        elif [ "$NODE_NAME" = "cluster-node-205" ]; then
            log_message "${YELLOW}Lenovo laptop ($NODE_NAME) may need to be started manually${NC}"
        fi
    fi
    
    # If node is reachable, check if Docker is running
    if ping -c 1 -W 2 "$NODE_IP" &> /dev/null; then
        # Determine the expected node name in Docker Swarm
        DOCKER_NODE_NAME="$NODE_NAME"
        if [ "$NODE_NAME" = "cluster-node-205" ]; then
            DOCKER_NODE_NAME="docker-desktop"
        fi
        
        # Check if node is already in the swarm
        if docker node ls --format '{{.Hostname}}' | grep -q "$DOCKER_NODE_NAME"; then
            log_message "✓ Node $DOCKER_NODE_NAME is already in the swarm"
            
            # Ensure node has appropriate label
            NODE_ID=$(docker node ls --format '{{.ID}} {{.Hostname}}' | grep "$DOCKER_NODE_NAME" | awk '{print $1}')
            NODE_LABELS=$(docker node inspect "$NODE_ID" --format '{{.Spec.Labels}}')
            
            if ! echo "$NODE_LABELS" | grep -q "type=$NODE_TYPE"; then
                log_message "Adding type=$NODE_TYPE label to $DOCKER_NODE_NAME..."
                docker node update --label-add "type=$NODE_TYPE" "$NODE_ID"
                log_message "✓ Added type=$NODE_TYPE label to $DOCKER_NODE_NAME"
            fi
            
            # Check if node is active
            NODE_STATUS=$(docker node inspect "$NODE_ID" --format '{{.Status.State}}')
            if [ "$NODE_STATUS" != "ready" ]; then
                log_message "${YELLOW}Node $DOCKER_NODE_NAME is in state $NODE_STATUS, may need attention${NC}"
            fi
        else
            log_message "${YELLOW}Node $NODE_NAME is online but not in the swarm${NC}"
            
            # For Lenovo laptop, provide instructions
            if [ "$NODE_NAME" = "cluster-node-205" ]; then
                log_message "To add Lenovo laptop to swarm, run the following on the Windows laptop:"
                log_message "docker swarm join --token $JOIN_TOKEN 192.168.0.200:2377"
            else
                # For Linux nodes, attempt to join them to the swarm remotely
                log_message "Attempting to connect to $NODE_NAME via SSH and join swarm..."
                ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$NODE_IP" "docker swarm join --token $JOIN_TOKEN 192.168.0.200:2377" || log_message "${RED}Failed to join $NODE_NAME to swarm${NC}"
            fi
        fi
    fi
done

# Check for Samsung A50 mobile node
log_message "Checking for Samsung A50 mobile node..."
if ping -c 1 -W 2 192.168.0.210 &> /dev/null; then
    log_message "✓ Samsung A50 is reachable at 192.168.0.210"
    # Try to connect to SSH on the mobile device (port 8022)
    if nc -z -w 5 192.168.0.210 8022; then
        log_message "✓ SSH service is running on Samsung A50"
        
        # Try multiple possible users for Termux
        DOCKER_RUNNING=false
        for USER_PREFIX in "u0_a" "shell" "root"; do
            USER_ID="${USER_PREFIX}$(id -u 2>/dev/null || echo "10")"
            
            if ssh -p 8022 -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$USER_ID@192.168.0.210" "command -v docker" &>/dev/null; then
                log_message "✓ Connected to Samsung A50 with user $USER_ID"
                
                # Attempt to run Docker
                if ssh -p 8022 -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$USER_ID@192.168.0.210" "docker info"; then
                    log_message "✓ Docker is running on Samsung A50"
                    DOCKER_RUNNING=true
                    
                    # Check if the node is in swarm
                    NODE_STATUS=$(ssh -p 8022 -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$USER_ID@192.168.0.210" "docker info --format '{{.Swarm.LocalNodeState}}'" 2>/dev/null)
                    if [ "$NODE_STATUS" = "active" ]; then
                        log_message "✓ Samsung A50 is already in the swarm"
                    else
                        log_message "${YELLOW}Samsung A50 is not in swarm, attempting to join...${NC}"
                        ssh -p 8022 -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$USER_ID@192.168.0.210" "docker swarm join --token $JOIN_TOKEN 192.168.0.200:2377"
                    fi
                    
                    break
                else
                    log_message "${YELLOW}Docker found but not running on Samsung A50${NC}"
                    log_message "Attempting to start Docker..."
                    ssh -p 8022 -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$USER_ID@192.168.0.210" "termux-wake-lock && docker start" || log_message "${RED}Failed to start Docker on Samsung A50${NC}"
                fi
            fi
        done
        
        if [ "$DOCKER_RUNNING" = false ]; then
            log_message "${YELLOW}Docker not responding on Samsung A50, may need setup${NC}"
            log_message "To set up Samsung A50, run the mobile setup script:"
            log_message "cd /home/optiplex_780_1/Desktop/mobile_node_project && ./quick_start.sh"
        fi
    else
        log_message "${YELLOW}SSH service not detected on Samsung A50${NC}"
    fi
else
    log_message "${YELLOW}Samsung A50 mobile node not detected on network${NC}"
fi

# Check for HP laptop
log_message "Checking for HP laptop..."
if ping -c 1 -W 2 192.168.0.204 &> /dev/null; then
    log_message "✓ HP laptop is reachable at 192.168.0.204"
    
    # Try to connect via SSH to check Docker status
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 Administrator@192.168.0.204 "powershell -Command \"(Get-Service -Name docker).Status\"" 2>/dev/null | grep -q "Running"; then
        log_message "✓ Docker service is running on HP laptop"
        
        # Check if node is already in swarm
        SWARM_STATUS=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 Administrator@192.168.0.204 "powershell -Command \"docker info --format '{{.Swarm.LocalNodeState}}'\"" 2>/dev/null)
        if [ "$SWARM_STATUS" = "active" ]; then
            log_message "✓ HP laptop is already in the swarm"
        else
            log_message "${YELLOW}HP laptop is not in swarm, attempting to join...${NC}"
            ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 Administrator@192.168.0.204 "powershell -Command \"docker swarm join --token $JOIN_TOKEN 192.168.0.200:2377\"" || log_message "${RED}Failed to join HP laptop to swarm${NC}"
        fi
    else
        log_message "${YELLOW}Docker service is not running on HP laptop${NC}"
        log_message "Attempting to start Docker service..."
        ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 Administrator@192.168.0.204 "powershell -Command \"Start-Service docker\"" || log_message "${RED}Failed to start Docker on HP laptop${NC}"
        
        # Provide instructions as fallback
        log_message "To manually add HP laptop to swarm, run the following on the laptop:"
        log_message "docker swarm join --token $JOIN_TOKEN 192.168.0.200:2377"
    fi
else
    log_message "${YELLOW}HP laptop not detected on network${NC}"
    
    # Try to wake up HP laptop if it has a known MAC address
    HP_MAC="$(arp -n | grep "192.168.0.204" | awk '{print $3}' | head -n 1)"
    if [ -n "$HP_MAC" ]; then
        log_message "Attempting to wake HP laptop with MAC: $HP_MAC"
        wakeonlan "$HP_MAC" 2>/dev/null || etherwake "$HP_MAC" 2>/dev/null
        
        # Wait for laptop to boot
        log_message "Waiting for HP laptop to boot..."
        for i in {1..30}; do
            if ping -c 1 -W 2 192.168.0.204 &> /dev/null; then
                log_message "✓ HP laptop is now online"
                break
            fi
            if [ $i -eq 30 ]; then
                log_message "${RED}Timed out waiting for HP laptop to respond${NC}"
            fi
            sleep 2
        done
    else
        log_message "${YELLOW}Cannot wake HP laptop - MAC address unknown${NC}"
    fi
fi

# Display current swarm status
log_message "Current Docker Swarm status:"
docker node ls

# Verify essential services are running
log_message "Checking essential services..."
if ! docker service ls --filter name=visualizer | grep -q visualizer; then
    log_message "Deploying Swarm Visualizer..."
    docker service create \
        --name visualizer \
        --publish 8080:8080 \
        --constraint node.role==manager \
        --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
        dockersamples/visualizer
    log_message "✓ Swarm Visualizer deployed"
fi

log_message "✓ Node startup sequence completed successfully"
echo -e "${GREEN}All available nodes have been started and integrated into the swarm${NC}"
echo -e "${YELLOW}View swarm status at http://192.168.0.200:8080${NC}"
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
