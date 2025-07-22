#!/bin/bash

# Installation script for Docker Swarm Cluster Management Scripts
# This script installs the startup and shutdown scripts and configures them to run automatically

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}This script must be run as root (use sudo)${NC}"
  exit 1
fi

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}     DOCKER SWARM CLUSTER MANAGEMENT INSTALLER      ${NC}"
echo -e "${BLUE}====================================================${NC}"
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
STARTUP_SCRIPT="$SCRIPT_DIR/node_startup.sh"
SHUTDOWN_SCRIPT="$SCRIPT_DIR/node_shutdown.sh"

echo -e "${YELLOW}Step 1: Making scripts executable...${NC}"
chmod +x "$STARTUP_SCRIPT"
chmod +x "$SHUTDOWN_SCRIPT"
echo -e "${GREEN}✓ Scripts are now executable${NC}"

echo -e "${YELLOW}Step 2: Copying scripts to system directories...${NC}"
cp "$STARTUP_SCRIPT" /usr/local/bin/node_startup.sh
cp "$SHUTDOWN_SCRIPT" /usr/local/bin/node_shutdown.sh
echo -e "${GREEN}✓ Scripts copied to /usr/local/bin/${NC}"

echo -e "${YELLOW}Step 3: Creating systemd service for node startup...${NC}"
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
echo -e "${GREEN}✓ Node startup service created${NC}"

echo -e "${YELLOW}Step 4: Creating systemd service for node shutdown...${NC}"
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
echo -e "${GREEN}✓ Node shutdown service created${NC}"

echo -e "${YELLOW}Step 5: Enabling services...${NC}"
systemctl daemon-reload
systemctl enable node-startup.service
systemctl enable node-shutdown.service
echo -e "${GREEN}✓ Services enabled${NC}"

echo -e "${YELLOW}Step 6: Creating status check script...${NC}"
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
if ping -c 1 -W 2 "192.168.0.206" &> /dev/null; then
    check_node "hp-laptop" "192.168.0.206" "laptop"
fi
if ping -c 1 -W 2 "192.168.0.210" &> /dev/null; then
    echo -ne "\${BOLD}Samsung A50${NC} (192.168.0.210, mobile): "
    echo -e "\${GREEN}reachable${NC} (mobile devices managed separately)"
fi

echo -e "\n\${BLUE}====================================================${NC}"
echo -e "\${BLUE}     SWARM VISUALIZER: http://192.168.0.200:8080    ${NC}"
echo -e "\${BLUE}====================================================${NC}"
EOL

chmod +x /usr/local/bin/cluster-status.sh
echo -e "${GREEN}✓ Status check script created${NC}"

echo -e "${YELLOW}Step 7: Setting up desktop shortcut...${NC}"
cat > /home/optiplex_780_1/Desktop/Cluster_Status.desktop << EOL
[Desktop Entry]
Type=Application
Terminal=true
Name=Docker Swarm Cluster Status
Exec=/usr/local/bin/cluster-status.sh
Icon=utilities-terminal
Comment=Check the status of the Docker Swarm cluster
Path=/home/optiplex_780_1/Desktop
EOL

chmod +x /home/optiplex_780_1/Desktop/Cluster_Status.desktop
echo -e "${GREEN}✓ Desktop shortcut created${NC}"

echo -e "${YELLOW}Step 8: Testing startup script...${NC}"
echo -e "${YELLOW}Do you want to run the startup script now? (y/n)${NC}"
read -r RESPONSE
if [[ "$RESPONSE" =~ ^[Yy]$ ]]; then
    /usr/local/bin/node_startup.sh
    echo -e "${GREEN}✓ Startup script executed${NC}"
else
    echo -e "${YELLOW}Startup script test skipped. You can run it manually with:${NC}"
    echo -e "   sudo /usr/local/bin/node_startup.sh"
fi

echo
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}     INSTALLATION COMPLETE                          ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo
echo -e "The Docker Swarm Cluster Management scripts have been installed."
echo -e "- Startup script will run automatically when the system boots"
echo -e "- Shutdown script will run automatically when the system shuts down"
echo -e "- You can check cluster status with: ${YELLOW}sudo /usr/local/bin/cluster-status.sh${NC}"
echo -e "- Or by using the desktop shortcut"
echo
echo -e "${YELLOW}Note: For the shutdown script to work properly, always shut down${NC}"
echo -e "${YELLOW}      the system using the GUI or 'shutdown' command.${NC}"
echo
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
