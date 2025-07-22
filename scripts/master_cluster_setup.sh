#!/bin/bash

# Master Docker Swarm Cluster Setup and Maintenance Script
# This script orchestrates the entire Docker Swarm cluster configuration and management

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Log function
log_message() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}This script must be run as root (use sudo)${NC}"
  exit 1
fi

# Record start time
START_TIME=$(date +%s)

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}     DOCKER SWARM CLUSTER MASTER SETUP SCRIPT       ${NC}"
echo -e "${BLUE}====================================================${NC}"
echo

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
BLUEPRINT_DIR="$(dirname "$SCRIPT_DIR")"
DESKTOP_DIR="/home/optiplex_780_1/Desktop"

# Create data directory if it doesn't exist
mkdir -p "$BLUEPRINT_DIR/data"

# Make all scripts executable
log_message "Making all scripts executable..."
chmod +x "$SCRIPT_DIR"/*.sh
log_message "✓ All scripts are now executable"

# Function to initialize the swarm
initialize_swarm() {
    log_message "Checking Docker service status..."
    if ! systemctl is-active --quiet docker; then
        log_message "Starting Docker service..."
        systemctl start docker
        systemctl enable docker
    fi
    log_message "✓ Docker service is running"
    
    # Check if already in a swarm
    SWARM_STATUS=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)
    if [ "$SWARM_STATUS" = "active" ]; then
        NODE_ROLE=$(docker info --format '{{.Swarm.ControlAvailable}}')
        if [ "$NODE_ROLE" = "true" ]; then
            log_message "✓ Master node is already active as swarm manager"
            return 0
        else
            log_message "${YELLOW}Master node is in swarm but not as manager, reinitializing...${NC}"
            docker swarm leave --force
        fi
    fi
    
    # Initialize new swarm
    log_message "Initializing new swarm with master as manager..."
    if docker swarm init --advertise-addr 192.168.0.200; then
        log_message "✓ New swarm initialized with this node as manager"
        
        # Add label to master node
        MASTER_NODE_ID=$(docker node ls --filter "role=manager" --format '{{.ID}}')
        docker node update --label-add role=manager "$MASTER_NODE_ID"
        log_message "✓ Added role=manager label to master node"
        return 0
    else
        log_message "${RED}✗ Failed to initialize swarm${NC}"
        return 1
    fi
}

# Function to install the management scripts
install_management_scripts() {
    log_message "Installing cluster management scripts..."
    
    # Check if install script exists
    if [ -f "$SCRIPT_DIR/install_scripts.sh" ]; then
        log_message "Running installer script..."
        "$SCRIPT_DIR/install_scripts.sh"
        
        if [ $? -eq 0 ]; then
            log_message "✓ Management scripts installed successfully"
            return 0
        else
            log_message "${RED}✗ Failed to install management scripts${NC}"
            return 1
        fi
    else
        log_message "${YELLOW}No installer script found, creating systemd services manually...${NC}"
        
        # Copy scripts to system directories
        cp "$SCRIPT_DIR/node_startup.sh" /usr/local/bin/node_startup.sh
        cp "$SCRIPT_DIR/node_shutdown.sh" /usr/local/bin/node_shutdown.sh
        chmod +x /usr/local/bin/node_startup.sh
        chmod +x /usr/local/bin/node_shutdown.sh
        
        # Create systemd services
        cat > /etc/systemd/system/node-startup.service << EOL
[Unit]
Description=Docker Swarm Node Startup Service
After=network.target docker.service
Wants=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/node_startup.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOL

        cat > /etc/systemd/system/node-shutdown.service << EOL
[Unit]
Description=Docker Swarm Node Shutdown Service
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target
Conflicts=reboot.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/node_shutdown.sh
TimeoutStartSec=120
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=shutdown.target reboot.target halt.target
EOL

        # Create status script
        cat > /usr/local/bin/cluster-status.sh << EOL
#!/bin/bash
# Docker Swarm Cluster Status Script

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "\${BLUE}====================================================${NC}"
echo -e "\${BLUE}     DOCKER SWARM CLUSTER STATUS REPORT             ${NC}"
echo -e "\${BLUE}====================================================${NC}"
echo

# Check if Docker is running
if systemctl is-active --quiet docker; then
    echo -e "\${GREEN}✓ Docker service is running${NC}"
else
    echo -e "\${RED}✗ Docker service is not running${NC}"
    exit 1
fi

# Check swarm status
SWARM_STATUS=\$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)
if [ "\$SWARM_STATUS" = "active" ]; then
    NODE_ROLE=\$(docker info --format '{{.Swarm.ControlAvailable}}')
    if [ "\$NODE_ROLE" = "true" ]; then
        echo -e "\${GREEN}✓ Node is active as a swarm manager${NC}"
    else
        echo -e "\${YELLOW}✗ Node is in swarm but not as manager${NC}"
    fi
else
    echo -e "\${RED}✗ Node is not part of Docker swarm${NC}"
    exit 1
fi

# Get node status
echo -e "\n\${BOLD}NODE STATUS:${NC}"
docker node ls

# Get service status
echo -e "\n\${BOLD}SERVICE STATUS:${NC}"
docker service ls

# Check for specific nodes
echo -e "\n\${BOLD}SPECIFIC NODE STATUS:${NC}"

check_node() {
    NODE_NAME=\$1
    NODE_IP=\$2
    NODE_TYPE=\$3
    
    echo -ne "\${BOLD}\$NODE_NAME${NC} (\$NODE_IP, \$NODE_TYPE): "
    
    if ping -c 1 -W 2 "\$NODE_IP" &> /dev/null; then
        echo -ne "\${GREEN}reachable${NC}, "
        
        # Check if in swarm
        if docker node ls --format '{{.Hostname}}' | grep -q "\$NODE_NAME"; then
            NODE_ID=\$(docker node ls --format '{{.ID}} {{.Hostname}}' | grep "\$NODE_NAME" | awk '{print \$1}')
            NODE_STATUS=\$(docker node inspect "\$NODE_ID" --format '{{.Status.State}}')
            
            if [ "\$NODE_STATUS" = "ready" ]; then
                echo -e "\${GREEN}active in swarm${NC}"
            else
                echo -e "\${YELLOW}in swarm but state is \$NODE_STATUS${NC}"
            fi
        else
            echo -e "\${RED}not in swarm${NC}"
        fi
    else
        echo -e "\${RED}not reachable${NC}"
    fi
}

check_node "master" "192.168.0.200" "manager"
check_node "optiplex70101" "192.168.0.202" "server"
check_node "optiplex70102" "192.168.0.203" "server"
check_node "docker-desktop" "192.168.0.205" "laptop"
check_node "hp-laptop" "192.168.0.206" "laptop"

if ping -c 1 -W 2 "192.168.0.210" &> /dev/null; then
    echo -ne "\${BOLD}Samsung A50${NC} (192.168.0.210, mobile): "
    echo -e "\${GREEN}reachable${NC} (mobile devices managed separately)"
fi

echo -e "\n\${BLUE}====================================================${NC}"
echo -e "\${BLUE}     SWARM VISUALIZER: http://192.168.0.200:8080    ${NC}"
echo -e "\${BLUE}====================================================${NC}"
EOL

        chmod +x /usr/local/bin/cluster-status.sh
        
        # Enable services
        systemctl daemon-reload
        systemctl enable node-startup.service
        systemctl enable node-shutdown.service
        
        # Create desktop shortcut
        cat > "$DESKTOP_DIR/Cluster_Status.desktop" << EOL
[Desktop Entry]
Type=Application
Terminal=true
Name=Docker Swarm Cluster Status
Exec=/usr/local/bin/cluster-status.sh
Icon=utilities-terminal
Comment=Check the status of the Docker Swarm cluster
Path=$DESKTOP_DIR
EOL

        chmod +x "$DESKTOP_DIR/Cluster_Status.desktop"
        
        log_message "✓ Management scripts and services installed manually"
        return 0
    fi
}

# Function to set up monitoring and visualization
setup_monitoring() {
    log_message "Setting up cluster monitoring and visualization..."
    
    # Check if visualizer is already running
    if ! docker service ls --filter name=visualizer | grep -q visualizer; then
        log_message "Deploying Swarm Visualizer..."
        docker service create \
            --name visualizer \
            --publish 8080:8080 \
            --constraint node.role==manager \
            --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
            dockersamples/visualizer
        
        if [ $? -eq 0 ]; then
            log_message "✓ Swarm Visualizer deployed successfully"
        else
            log_message "${RED}✗ Failed to deploy Swarm Visualizer${NC}"
        fi
    else
        log_message "✓ Swarm Visualizer is already running"
    fi
    
    # Check if we need to set up Prometheus monitoring
    if [ -d "$DESKTOP_DIR/monitoring" ] && [ -f "$DESKTOP_DIR/monitoring/docker-compose.yml" ]; then
        log_message "Setting up Prometheus monitoring..."
        cd "$DESKTOP_DIR/monitoring"
        
        # Deploy the monitoring stack
        docker stack deploy -c docker-compose.yml monitoring
        
        if [ $? -eq 0 ]; then
            log_message "✓ Prometheus monitoring stack deployed successfully"
        else
            log_message "${RED}✗ Failed to deploy Prometheus monitoring stack${NC}"
        fi
        
        cd - > /dev/null
    else
        log_message "${YELLOW}No monitoring configuration found, skipping Prometheus setup${NC}"
    fi
}

# Function to create easy-access shortcuts
create_shortcuts() {
    log_message "Creating easy-access desktop shortcuts..."
    
    # Create a shortcut for the master script
    cat > "$DESKTOP_DIR/Cluster_Master_Control.desktop" << EOL
[Desktop Entry]
Type=Application
Terminal=true
Name=Docker Swarm Master Control
Exec=sudo $SCRIPT_DIR/master_cluster_setup.sh
Icon=utilities-terminal
Comment=Master control script for Docker Swarm cluster
Path=$DESKTOP_DIR
EOL
    chmod +x "$DESKTOP_DIR/Cluster_Master_Control.desktop"
    
    # Create shortcut for HP laptop setup
    cat > "$DESKTOP_DIR/Add_HP_Laptop.desktop" << EOL
[Desktop Entry]
Type=Application
Terminal=true
Name=Add HP Laptop to Swarm
Exec=sudo $SCRIPT_DIR/add_hp_laptop.sh
Icon=utilities-terminal
Comment=Add HP laptop to Docker Swarm cluster
Path=$DESKTOP_DIR
EOL
    chmod +x "$DESKTOP_DIR/Add_HP_Laptop.desktop"
    
    # Create shortcut for Lenovo laptop setup
    cat > "$DESKTOP_DIR/Add_Lenovo_Laptop.desktop" << EOL
[Desktop Entry]
Type=Application
Terminal=true
Name=Add Lenovo Laptop to Swarm
Exec=sudo $SCRIPT_DIR/add_lenovo_laptop.sh
Icon=utilities-terminal
Comment=Add Lenovo laptop to Docker Swarm cluster
Path=$DESKTOP_DIR
EOL
    chmod +x "$DESKTOP_DIR/Add_Lenovo_Laptop.desktop"
    
    # Create shortcut for Samsung A50 setup
    cat > "$DESKTOP_DIR/Add_Samsung_A50.desktop" << EOL
[Desktop Entry]
Type=Application
Terminal=true
Name=Add Samsung A50 to Swarm
Exec=sudo $SCRIPT_DIR/add_samsung_a50.sh
Icon=utilities-terminal
Comment=Add Samsung A50 to Docker Swarm cluster
Path=$DESKTOP_DIR
EOL
    chmod +x "$DESKTOP_DIR/Add_Samsung_A50.desktop"
    
    # Create shortcut for cluster info collection
    cat > "$DESKTOP_DIR/Collect_Cluster_Info.desktop" << EOL
[Desktop Entry]
Type=Application
Terminal=true
Name=Collect Cluster Information
Exec=sudo $SCRIPT_DIR/collect_cluster_info.sh
Icon=utilities-terminal
Comment=Collect comprehensive information about the Docker Swarm cluster
Path=$DESKTOP_DIR
EOL
    chmod +x "$DESKTOP_DIR/Collect_Cluster_Info.desktop"
    
    log_message "✓ Desktop shortcuts created successfully"
}

# Function to implement load balancing
setup_load_balancing() {
    log_message "Setting up cluster load balancing..."
    
    # Create a network for load balanced services if it doesn't exist
    if ! docker network ls | grep -q "loadbalance-net"; then
        log_message "Creating overlay network for load balanced services..."
        docker network create --driver overlay --attachable loadbalance-net
        
        if [ $? -eq 0 ]; then
            log_message "✓ Load balancing network created successfully"
        else
            log_message "${RED}✗ Failed to create load balancing network${NC}"
            return 1
        fi
    else
        log_message "✓ Load balancing network already exists"
    fi
    
    # Create load balancing script
    mkdir -p "$BLUEPRINT_DIR/loadbalance"
    
    LOADBALANCE_SCRIPT="$BLUEPRINT_DIR/loadbalance/setup_load_balancer.sh"
    cat > "$LOADBALANCE_SCRIPT" << EOL
#!/bin/bash

# Load Balancer Setup Script for Docker Swarm
# This script deploys Traefik as a load balancer for the swarm

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "\${BLUE}====================================================${NC}"
echo -e "\${BLUE}     DOCKER SWARM LOAD BALANCER SETUP               ${NC}"
echo -e "\${BLUE}====================================================${NC}"
echo

# Check if running as root
if [ "\$EUID" -ne 0 ]; then
  echo -e "\${RED}This script must be run as root (use sudo)${NC}"
  exit 1
fi

# Check if we're in swarm mode
SWARM_STATUS=\$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)
if [ "\$SWARM_STATUS" != "active" ]; then
    echo -e "\${RED}Not in an active swarm. Please initialize swarm first.${NC}"
    exit 1
fi

# Check if we're a manager
NODE_ROLE=\$(docker info --format '{{.Swarm.ControlAvailable}}')
if [ "\$NODE_ROLE" != "true" ]; then
    echo -e "\${RED}This node is not a swarm manager. Cannot deploy services.${NC}"
    exit 1
fi

# Create Traefik configuration
echo -e "\${YELLOW}Creating Traefik configuration...${NC}"
mkdir -p /opt/traefik
cat > /opt/traefik/traefik.toml << TOML
[entryPoints]
  [entryPoints.web]
    address = ":80"
  [entryPoints.websecure]
    address = ":443"

[api]
  dashboard = true
  insecure = true

[providers]
  [providers.docker]
    endpoint = "unix:///var/run/docker.sock"
    swarmMode = true
    watch = true
    exposedByDefault = false

[accessLog]
TOML

# Create Docker Compose file for Traefik
cat > /opt/traefik/docker-compose.yml << YAML
version: '3.8'

services:
  traefik:
    image: traefik:v2.9
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.swarmMode=true"
      - "--providers.docker.exposedByDefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
    ports:
      - "80:80"
      - "443:443"
      - "8000:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /opt/traefik/traefik.toml:/etc/traefik/traefik.toml
    networks:
      - loadbalance-net
    deploy:
      placement:
        constraints:
          - node.role == manager
      restart_policy:
        condition: on-failure
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.dashboard.rule=Host(\`traefik.local\`)"
        - "traefik.http.routers.dashboard.service=api@internal"
        - "traefik.http.services.dashboard.loadbalancer.server.port=8080"

networks:
  loadbalance-net:
    external: true
YAML

# Deploy Traefik
echo -e "\${YELLOW}Deploying Traefik load balancer...${NC}"
docker stack deploy -c /opt/traefik/docker-compose.yml loadbalancer

if [ \$? -eq 0 ]; then
    echo -e "\${GREEN}✓ Traefik load balancer deployed successfully${NC}"
    echo -e "\${GREEN}✓ Traefik dashboard available at http://localhost:8000${NC}"
    echo -e "\${GREEN}✓ To use with services, add these labels to your services:${NC}"
    echo -e "  - traefik.enable=true"
    echo -e "  - traefik.http.routers.<name>.rule=Host(\`<hostname>\`)"
    echo -e "  - traefik.http.services.<name>.loadbalancer.server.port=<port>"
    echo -e "\n\${YELLOW}To see all running services:${NC}"
    docker service ls
else
    echo -e "\${RED}✗ Failed to deploy Traefik load balancer${NC}"
fi

echo -e "\${BLUE}====================================================${NC}"
EOL

    chmod +x "$LOADBALANCE_SCRIPT"
    
    # Create desktop shortcut for load balancer
    cat > "$DESKTOP_DIR/Setup_Load_Balancer.desktop" << EOL
[Desktop Entry]
Type=Application
Terminal=true
Name=Setup Load Balancer
Exec=sudo $LOADBALANCE_SCRIPT
Icon=utilities-terminal
Comment=Set up Traefik load balancer for Docker Swarm
Path=$DESKTOP_DIR
EOL
    chmod +x "$DESKTOP_DIR/Setup_Load_Balancer.desktop"
    
    log_message "✓ Load balancing setup complete"
}

# Main execution
# Step 1: Initialize the swarm
log_message "STEP 1: Initializing Docker Swarm..."
initialize_swarm
if [ $? -ne 0 ]; then
    log_message "${RED}Failed to initialize swarm. Exiting.${NC}"
    exit 1
fi

# Step 2: Install management scripts
log_message "STEP 2: Installing cluster management scripts..."
install_management_scripts
if [ $? -ne 0 ]; then
    log_message "${YELLOW}Warning: Issue with management script installation${NC}"
fi

# Step 3: Set up monitoring and visualization
log_message "STEP 3: Setting up monitoring and visualization..."
setup_monitoring

# Step 4: Setup load balancing
log_message "STEP 4: Setting up load balancing..."
setup_load_balancing

# Step 5: Create convenience shortcuts
log_message "STEP 5: Creating convenience shortcuts..."
create_shortcuts

# Step 6: Start existing worker nodes
log_message "STEP 6: Starting existing worker nodes..."
log_message "Running node startup script..."
/usr/local/bin/node_startup.sh

# Final step: Generate/update blueprint documentation
log_message "STEP 7: Generating cluster blueprint document..."
"$SCRIPT_DIR/collect_cluster_info.sh"

# Display completion message
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}     DOCKER SWARM CLUSTER SETUP COMPLETE            ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo
log_message "Setup completed in $MINUTES minutes and $SECONDS seconds"
echo
log_message "Next steps:"
echo "1. To add the HP laptop to the cluster:"
echo "   sudo $SCRIPT_DIR/add_hp_laptop.sh"
echo
echo "2. To add the Lenovo laptop to the cluster:"
echo "   sudo $SCRIPT_DIR/add_lenovo_laptop.sh"
echo
echo "3. To add the Samsung A50 to the cluster:"
echo "   sudo $SCRIPT_DIR/add_samsung_a50.sh"
echo
echo "4. To check cluster status:"
echo "   sudo /usr/local/bin/cluster-status.sh"
echo
echo "Desktop shortcuts have been created for common tasks."
echo -e "${BLUE}====================================================${NC}"
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
