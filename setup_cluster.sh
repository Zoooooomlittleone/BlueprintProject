#!/bin/bash

# Master setup script for Docker Swarm Cluster Blueprint
# This script guides the user through the setup process

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}This script must be run as root (use sudo)${NC}"
  exit 1
fi

clear
echo -e "${BLUE}========================================================================${NC}"
echo -e "${BLUE}     DOCKER SWARM CLUSTER BLUEPRINT - MASTER SETUP SCRIPT             ${NC}"
echo -e "${BLUE}========================================================================${NC}"
echo
echo -e "This script will guide you through setting up your Docker Swarm cluster"
echo -e "according to the blueprint specifications."
echo

# Function to check for dependencies
check_dependencies() {
    echo -e "${YELLOW}Checking for required dependencies...${NC}"
    local missing=false
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}✗ Docker is not installed${NC}"
        missing=true
    else
        echo -e "${GREEN}✓ Docker is installed${NC}"
    fi
    
    # Check SSH
    if ! command -v ssh &> /dev/null; then
        echo -e "${RED}✗ SSH client is not installed${NC}"
        missing=true
    else
        echo -e "${GREEN}✓ SSH client is installed${NC}"
    fi
    
    # Check wakeonlan/etherwake
    if ! command -v wakeonlan &> /dev/null && ! command -v etherwake &> /dev/null; then
        echo -e "${RED}✗ Neither wakeonlan nor etherwake is installed${NC}"
        missing=true
    else
        echo -e "${GREEN}✓ Wake-on-LAN tools are installed${NC}"
    fi
    
    if [ "$missing" = true ]; then
        echo
        echo -e "${YELLOW}Would you like to install missing dependencies? (y/n)${NC}"
        read -r install_deps
        if [[ "$install_deps" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Installing missing dependencies...${NC}"
            apt update
            
            if ! command -v docker &> /dev/null; then
                apt install -y docker.io
            fi
            
            if ! command -v ssh &> /dev/null; then
                apt install -y openssh-client
            fi
            
            if ! command -v wakeonlan &> /dev/null && ! command -v etherwake &> /dev/null; then
                apt install -y wakeonlan etherwake
            fi
            
            echo -e "${GREEN}Dependencies installed${NC}"
        else
            echo -e "${RED}Please install the missing dependencies and run this script again${NC}"
            exit 1
        fi
    fi
}

# Function to check Docker swarm status
check_swarm() {
    echo -e "${YELLOW}Checking Docker swarm status...${NC}"
    
    # Check if Docker is running
    if ! systemctl is-active --quiet docker; then
        echo -e "${RED}Docker service is not running${NC}"
        echo -e "${YELLOW}Starting Docker service...${NC}"
        systemctl start docker
        systemctl enable docker
    fi
    
    # Check swarm status
    SWARM_STATUS=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)
    
    if [ "$SWARM_STATUS" = "active" ]; then
        NODE_ROLE=$(docker info --format '{{.Swarm.ControlAvailable}}')
        if [ "$NODE_ROLE" = "true" ]; then
            echo -e "${GREEN}✓ Node is already active as a swarm manager${NC}"
            return 0
        else
            echo -e "${YELLOW}Node is in swarm but not as manager${NC}"
            echo -e "${YELLOW}Would you like to leave the swarm and reinitialize as manager? (y/n)${NC}"
            read -r reinit_swarm
            if [[ "$reinit_swarm" =~ ^[Yy]$ ]]; then
                docker swarm leave --force
            else
                echo -e "${RED}Cannot proceed without manager privileges${NC}"
                exit 1
            fi
        fi
    fi
    
    if [ "$SWARM_STATUS" != "active" ] || [[ "$reinit_swarm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Initializing swarm as manager...${NC}"
        docker swarm init --advertise-addr 192.168.0.200
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Swarm initialized successfully${NC}"
            return 0
        else
            echo -e "${RED}Failed to initialize swarm${NC}"
            exit 1
        fi
    fi
}

# Function to install scripts
install_scripts() {
    echo -e "${YELLOW}Installing management scripts...${NC}"
    
    SCRIPT_DIR="/home/optiplex_780_1/Desktop/BlueprintProject/scripts"
    
    # Make scripts executable
    chmod +x "$SCRIPT_DIR/node_startup.sh"
    chmod +x "$SCRIPT_DIR/node_shutdown.sh"
    chmod +x "$SCRIPT_DIR/install_scripts.sh"
    
    # Run the installer script
    "$SCRIPT_DIR/install_scripts.sh"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Management scripts installed successfully${NC}"
    else
        echo -e "${RED}Failed to install management scripts${NC}"
        exit 1
    fi
}

# Function to deploy visualizer
deploy_visualizer() {
    echo -e "${YELLOW}Deploying Swarm Visualizer...${NC}"
    
    # Check if visualizer is already running
    if docker service ls --filter name=visualizer | grep -q visualizer; then
        echo -e "${GREEN}✓ Visualizer is already deployed${NC}"
        return 0
    fi
    
    # Deploy visualizer
    docker service create \
        --name visualizer \
        --publish 8080:8080 \
        --constraint node.role==manager \
        --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
        dockersamples/visualizer
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Visualizer deployed successfully${NC}"
        echo -e "${GREEN}✓ Access the visualizer at http://192.168.0.200:8080${NC}"
    else
        echo -e "${RED}Failed to deploy visualizer${NC}"
    fi
}

# Function to prepare for additional nodes
prepare_nodes() {
    echo -e "${YELLOW}Preparing for additional worker nodes...${NC}"
    
    WORKER_TOKEN=$(docker swarm join-token worker -q)
    
    echo -e "${GREEN}✓ Worker join token: ${YELLOW}$WORKER_TOKEN${NC}"
    echo
    echo -e "${BOLD}To add worker nodes to the swarm:${NC}"
    echo -e "1. For Linux workers (Optiplex nodes):"
    echo -e "   Run: ${YELLOW}docker swarm join --token $WORKER_TOKEN 192.168.0.200:2377${NC}"
    echo
    echo -e "2. For Windows laptop workers (Lenovo and HP):"
    echo -e "   a. Copy the appropriate setup script to the laptop:"
    echo -e "      - Lenovo: /home/optiplex_780_1/Desktop/docker_swarm_config/lenovo_laptop_setup.ps1"
    echo -e "      - HP: /home/optiplex_780_1/Desktop/BlueprintProject/scripts/hp_laptop_setup.ps1"
    echo -e "   b. Run the script as Administrator in PowerShell"
    echo
    echo -e "3. For Samsung A50 mobile:"
    echo -e "   a. Ensure the device is on the same network"
    echo -e "   b. Run the mobile setup script from the master node:"
    echo -e "      ${YELLOW}cd /home/optiplex_780_1/Desktop/mobile_node_project/scripts${NC}"
    echo -e "      ${YELLOW}./mobile_node_auto_connect.sh${NC}"
    echo
    echo -e "${YELLOW}Would you like to copy the configuration files to a USB drive? (y/n)${NC}"
    read -r copy_to_usb
    
    if [[ "$copy_to_usb" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Please insert a USB drive and press Enter when ready${NC}"
        read -r
        
        USB_DRIVE=$(lsblk -o NAME,SIZE,MOUNTPOINT | grep -i "/media\|/mnt" | head -n 1 | awk '{print $3}')
        
        if [ -z "$USB_DRIVE" ]; then
            echo -e "${RED}No mounted USB drive found${NC}"
            echo -e "${YELLOW}Would you like to try to mount it manually? (y/n)${NC}"
            read -r mount_manually
            
            if [[ "$mount_manually" =~ ^[Yy]$ ]]; then
                echo -e "${YELLOW}Available devices:${NC}"
                lsblk -o NAME,SIZE,TYPE | grep -v "loop\|rom"
                echo -e "${YELLOW}Enter the device name (e.g., sdb1):${NC}"
                read -r device_name
                
                USB_DRIVE="/mnt/usb_temp"
                mkdir -p "$USB_DRIVE"
                mount "/dev/$device_name" "$USB_DRIVE"
                
                if [ $? -ne 0 ]; then
                    echo -e "${RED}Failed to mount the USB drive${NC}"
                    rmdir "$USB_DRIVE"
                    USB_DRIVE=""
                fi
            fi
        fi
        
        if [ -n "$USB_DRIVE" ]; then
            DEST_DIR="$USB_DRIVE/Docker_Swarm_Config"
            mkdir -p "$DEST_DIR"
            
            # Copy configuration files
            cp -r /home/optiplex_780_1/Desktop/BlueprintProject/docs "$DEST_DIR/"
            cp -r /home/optiplex_780_1/Desktop/BlueprintProject/scripts "$DEST_DIR/"
            cp /home/optiplex_780_1/Desktop/docker_swarm_config/lenovo_laptop_setup.ps1 "$DEST_DIR/"
            cp -r /home/optiplex_780_1/Desktop/mobile_node_project/scripts "$DEST_DIR/mobile_scripts"
            
            # Create a README file on the USB drive
            cat > "$DEST_DIR/README.txt" << EOL
DOCKER SWARM CLUSTER CONFIGURATION FILES
----------------------------------------

This USB drive contains all the necessary files to set up and configure
the Docker Swarm cluster nodes.

1. DOCUMENTATION
   - docs/cluster_blueprint.md - Complete cluster architecture and configuration

2. WORKER NODE SETUP
   - For Lenovo laptop: lenovo_laptop_setup.ps1
   - For HP laptop: scripts/hp_laptop_setup.ps1
   - For Samsung A50: mobile_scripts/mobile_node_auto_connect.sh

3. WORKER JOIN COMMAND
   Run this command on any worker node to join the swarm:
   
   docker swarm join --token $WORKER_TOKEN 192.168.0.200:2377

4. ACCESS THE VISUALIZER
   Once the cluster is set up, access the visualizer at:
   http://192.168.0.200:8080
EOL
            
            echo -e "${GREEN}✓ Configuration files copied to USB drive: $DEST_DIR${NC}"
            
            # Ask if the USB drive should be unmounted
            echo -e "${YELLOW}Would you like to unmount the USB drive now? (y/n)${NC}"
            read -r unmount_usb
            
            if [[ "$unmount_usb" =~ ^[Yy]$ ]]; then
                if [ "$USB_DRIVE" = "/mnt/usb_temp" ]; then
                    umount "$USB_DRIVE"
                    rmdir "$USB_DRIVE"
                    echo -e "${GREEN}✓ USB drive unmounted${NC}"
                else
                    echo -e "${YELLOW}Please unmount the USB drive from the file manager${NC}"
                fi
            fi
        fi
    fi
}

# Main script execution
check_dependencies
check_swarm
install_scripts
deploy_visualizer
prepare_nodes

echo
echo -e "${BLUE}========================================================================${NC}"
echo -e "${GREEN}                DOCKER SWARM CLUSTER SETUP COMPLETE                    ${NC}"
echo -e "${BLUE}========================================================================${NC}"
echo
echo -e "The master node has been configured successfully."
echo -e "Management scripts have been installed and configured to run automatically."
echo -e "The swarm visualizer is accessible at ${YELLOW}http://192.168.0.200:8080${NC}"
echo
echo -e "Next steps:"
echo -e "1. Add worker nodes to the swarm using the provided instructions"
echo -e "2. Test the power management system by rebooting the master node"
echo -e "3. Deploy services to the cluster"
echo
echo -e "For more information, refer to the blueprint documentation:"
echo -e "${YELLOW}/home/optiplex_780_1/Desktop/BlueprintProject/docs/cluster_blueprint.md${NC}"
echo
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
