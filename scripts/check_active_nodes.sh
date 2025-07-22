#!/bin/bash

# Check Active Nodes Script
# This script checks which nodes are active from the known node list

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}     ACTIVE NODE CHECKER                           ${NC}"
echo -e "${BLUE}====================================================${NC}"
echo

# List all known nodes and their expected IPs
declare -A NODES
NODES["master"]="192.168.0.200"
NODES["optiplex_780_2"]="192.168.0.201"
NODES["optiplex_7010_1"]="192.168.0.202"
NODES["optiplex_7010_2"]="192.168.0.203"
NODES["lenovo"]="192.168.0.205"
NODES["hp-laptop"]="192.168.0.206"  # This will be changed by update_hp_ip.sh if needed
NODES["samsung-a50"]="192.168.0.210"

# Count total and active nodes
TOTAL_NODES=${#NODES[@]}
ACTIVE_NODES=0

echo -e "${YELLOW}Checking ${TOTAL_NODES} known nodes...${NC}\n"

# Function to check if a node is active
check_node() {
    local name=$1
    local ip=$2
    
    echo -e "${BOLD}Checking $name ($ip)...${NC}"
    
    # Check if node is reachable
    if ping -c 1 -W 2 "$ip" &> /dev/null; then
        echo -e "${GREEN}✓ $name is reachable at $ip${NC}"
        ACTIVE_NODES=$((ACTIVE_NODES + 1))
        
        # Check if node is in Docker Swarm (skip for master, we're already on it)
        if [ "$name" != "master" ] && docker node ls &>/dev/null; then
            if docker node ls --format '{{.Hostname}}' | grep -q "$name"; then
                echo -e "${GREEN}✓ $name is in the Docker Swarm${NC}"
            else
                # Try with different hostname formats
                if [ "$name" = "lenovo" ] && docker node ls --format '{{.Hostname}}' | grep -q "docker-desktop"; then
                    echo -e "${GREEN}✓ $name is in the Docker Swarm (as docker-desktop)${NC}"
                elif docker node ls --format '{{.Hostname}}' | grep -q "${name/-/_}"; then
                    echo -e "${GREEN}✓ $name is in the Docker Swarm (with modified name)${NC}"
                else
                    echo -e "${RED}✗ $name is not in the Docker Swarm${NC}"
                    
                    # Suggest appropriate add command
                    if [[ "$name" == *"optiplex"* ]]; then
                        echo -e "  Run node_startup.sh to add server nodes"
                    elif [ "$name" = "lenovo" ]; then
                        echo -e "  Run add_lenovo_laptop.sh to add Lenovo laptop"
                    elif [ "$name" = "hp-laptop" ]; then
                        echo -e "  Run add_hp_laptop.sh to add HP laptop"
                    elif [ "$name" = "samsung-a50" ]; then
                        echo -e "  Run add_samsung_a50.sh to add Samsung A50"
                    fi
                fi
            fi
        fi
    else
        echo -e "${RED}✗ $name is not reachable at $ip${NC}"
        
        # For non-master nodes, suggest how to wake them
        if [ "$name" != "master" ]; then
            echo -e "  To wake up $name, try:"
            if [[ "$name" == *"optiplex"* ]]; then
                echo -e "  - Check power and network connection"
                echo -e "  - Run node_startup.sh to attempt Wake-on-LAN"
            elif [ "$name" = "lenovo" ]; then
                echo -e "  - Power on the Lenovo laptop"
                echo -e "  - Run add_lenovo_laptop.sh"
            elif [ "$name" = "hp-laptop" ]; then
                echo -e "  - Power on the HP laptop"
                echo -e "  - Verify IP address is correct (run Update_HP_Laptop_IP.sh)"
                echo -e "  - Run add_hp_laptop.sh"
            elif [ "$name" = "samsung-a50" ]; then
                echo -e "  - Open Termux on the Samsung A50"
                echo -e "  - Run add_samsung_a50.sh"
            fi
        fi
    fi
    
    echo
}

# Check each node
for name in "${!NODES[@]}"; do
    check_node "$name" "${NODES[$name]}"
done

# Show Docker Swarm status if available
if docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null | grep -q "active"; then
    echo -e "${YELLOW}Current Docker Swarm status:${NC}"
    docker node ls
    
    echo -e "\n${YELLOW}Services running in the swarm:${NC}"
    docker service ls
else
    echo -e "${RED}Not in an active Docker Swarm${NC}"
    echo -e "To initialize the swarm, run: docker swarm init --advertise-addr 192.168.0.200"
fi

# Show summary
echo -e "\n${YELLOW}Summary:${NC}"
echo -e "${GREEN}$ACTIVE_NODES${NC} out of ${TOTAL_NODES} nodes are active"

echo -e "\n${BLUE}====================================================${NC}"
echo -e "${BLUE}     CHECK COMPLETE                                ${NC}"
echo -e "${BLUE}====================================================${NC}"
echo
echo -e "${YELLOW}Recommendations:${NC}"
echo -e "1. For any offline nodes you want to use, power them on and check their connections"
echo -e "2. For nodes not in the swarm, use the appropriate add_*.sh script"
echo -e "3. If the HP laptop IP is incorrect, run Update_HP_Laptop_IP.sh"
echo -e "4. To make all scripts executable, run make_all_executable.sh"
echo
echo -e "You can run the full cluster setup with Docker_Swarm_Master_Control.desktop"
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
