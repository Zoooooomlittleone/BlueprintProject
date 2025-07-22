#!/bin/bash

# Verify Configuration Script
# This script checks that all the necessary components are in place

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}     VERIFYING DOCKER SWARM CLUSTER SETUP           ${NC}"
echo -e "${BLUE}====================================================${NC}"
echo

# Get the directory of this script
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
BLUEPRINT_DIR="$(dirname "$SCRIPT_DIR")"
DESKTOP_DIR="/home/optiplex_780_1/Desktop"

# Step 1: Check if all required scripts are present
echo -e "${YELLOW}Checking core scripts...${NC}"
REQUIRED_SCRIPTS=(
    "$SCRIPT_DIR/master_cluster_setup.sh"
    "$SCRIPT_DIR/collect_cluster_info.sh"
    "$SCRIPT_DIR/node_startup.sh"
    "$SCRIPT_DIR/node_shutdown.sh"
    "$SCRIPT_DIR/add_hp_laptop.sh"
    "$SCRIPT_DIR/add_lenovo_laptop.sh"
    "$SCRIPT_DIR/add_samsung_a50.sh"
    "$SCRIPT_DIR/make_all_executable.sh"
)

MISSING_SCRIPTS=0
for SCRIPT in "${REQUIRED_SCRIPTS[@]}"; do
    if [ -f "$SCRIPT" ]; then
        echo -e "✓ Found script: $(basename "$SCRIPT")"
    else
        echo -e "${RED}✗ Missing script: $(basename "$SCRIPT")${NC}"
        MISSING_SCRIPTS=$((MISSING_SCRIPTS + 1))
    fi
done

if [ $MISSING_SCRIPTS -eq 0 ]; then
    echo -e "${GREEN}✓ All core scripts are present${NC}"
else
    echo -e "${RED}✗ Missing $MISSING_SCRIPTS core scripts${NC}"
fi

# Step 2: Check if desktop shortcuts are present
echo -e "\n${YELLOW}Checking desktop shortcuts...${NC}"
REQUIRED_SHORTCUTS=(
    "$DESKTOP_DIR/Docker_Swarm_Master_Control.desktop"
    "$DESKTOP_DIR/Make_All_Scripts_Executable.desktop"
)

MISSING_SHORTCUTS=0
for SHORTCUT in "${REQUIRED_SHORTCUTS[@]}"; do
    if [ -f "$SHORTCUT" ]; then
        echo -e "✓ Found shortcut: $(basename "$SHORTCUT")"
    else
        echo -e "${RED}✗ Missing shortcut: $(basename "$SHORTCUT")${NC}"
        MISSING_SHORTCUTS=$((MISSING_SHORTCUTS + 1))
    fi
done

if [ $MISSING_SHORTCUTS -eq 0 ]; then
    echo -e "${GREEN}✓ All desktop shortcuts are present${NC}"
else
    echo -e "${RED}✗ Missing $MISSING_SHORTCUTS desktop shortcuts${NC}"
fi

# Step 3: Check if Docker and Docker Swarm are running
echo -e "\n${YELLOW}Checking Docker and Docker Swarm...${NC}"
if command -v docker &> /dev/null; then
    echo -e "✓ Docker is installed"
    
    if systemctl is-active --quiet docker; then
        echo -e "✓ Docker service is running"
    else
        echo -e "${RED}✗ Docker service is not running${NC}"
    fi
    
    # Check swarm status
    SWARM_STATUS=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)
    if [ "$SWARM_STATUS" = "active" ]; then
        NODE_ROLE=$(docker info --format '{{.Swarm.ControlAvailable}}')
        if [ "$NODE_ROLE" = "true" ]; then
            echo -e "✓ Node is active as a swarm manager"
        else
            echo -e "${YELLOW}✗ Node is in swarm but not as manager${NC}"
        fi
    else
        echo -e "${YELLOW}✗ Node is not part of Docker swarm${NC}"
    fi
else
    echo -e "${RED}✗ Docker is not installed${NC}"
fi

# Step 4: Check if nodes are reachable
echo -e "\n${YELLOW}Checking network connectivity to nodes...${NC}"
NODES=(
    "optiplex70101:192.168.0.202"
    "optiplex70102:192.168.0.203"
    "lenovo:192.168.0.205"
    "hp-laptop:192.168.0.206"
    "samsung-a50:192.168.0.210"
)

for NODE in "${NODES[@]}"; do
    NODE_NAME="${NODE%%:*}"
    NODE_IP="${NODE#*:}"
    
    if ping -c 1 -W 2 "$NODE_IP" &> /dev/null; then
        echo -e "✓ $NODE_NAME is reachable at $NODE_IP"
    else
        echo -e "${YELLOW}✗ $NODE_NAME is not reachable at $NODE_IP${NC}"
    fi
done

# Step 5: Display next steps
echo -e "\n${BLUE}====================================================${NC}"
echo -e "${BLUE}     VERIFICATION COMPLETE                          ${NC}"
echo -e "${BLUE}====================================================${NC}"
echo 
echo -e "${YELLOW}NEXT STEPS:${NC}"
echo -e "1. Make all scripts executable:"
echo -e "   Click the 'Make All Scripts Executable' desktop shortcut"
echo
echo -e "2. Run the master setup script:"
echo -e "   Click the 'Docker Swarm Master Control' desktop shortcut"
echo 
echo -e "3. Add additional nodes using the appropriate scripts"
echo
echo -e "4. Check cluster status using the status script"
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
