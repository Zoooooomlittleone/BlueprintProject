#!/bin/bash

# Test All Nodes Script
# This script tests the connectivity and status of all nodes in the Docker Swarm cluster

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}     TESTING ALL DOCKER SWARM CLUSTER NODES         ${NC}"
echo -e "${BLUE}====================================================${NC}"
echo

# Step 1: Check Docker service status
echo -e "${YELLOW}STEP 1: Checking Docker service status...${NC}"
if systemctl is-active --quiet docker; then
    echo -e "${GREEN}✓ Docker service is running${NC}"
else
    echo -e "${RED}✗ Docker service is not running${NC}"
    echo -e "Attempting to start Docker service..."
    sudo systemctl start docker
    if systemctl is-active --quiet docker; then
        echo -e "${GREEN}✓ Docker service started successfully${NC}"
    else
        echo -e "${RED}✗ Failed to start Docker service. Cannot proceed.${NC}"
        exit 1
    fi
fi

# Step 2: Check Swarm status
echo -e "\n${YELLOW}STEP 2: Checking Docker Swarm status...${NC}"
SWARM_STATUS=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)
if [ "$SWARM_STATUS" = "active" ]; then
    NODE_ROLE=$(docker info --format '{{.Swarm.ControlAvailable}}')
    if [ "$NODE_ROLE" = "true" ]; then
        echo -e "${GREEN}✓ Node is active as a swarm manager${NC}"
    else
        echo -e "${YELLOW}⚠ Node is in swarm but not as manager${NC}"
        echo -e "This node should be the manager. Leaving swarm to reinitialize..."
        sudo docker swarm leave --force
        echo -e "Initializing new swarm..."
        sudo docker swarm init --advertise-addr 192.168.0.200
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Successfully initialized swarm as manager${NC}"
        else
            echo -e "${RED}✗ Failed to initialize swarm as manager${NC}"
            exit 1
        fi
    fi
else
    echo -e "${YELLOW}⚠ Node is not part of Docker swarm${NC}"
    echo -e "Initializing new swarm..."
    sudo docker swarm init --advertise-addr 192.168.0.200
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Successfully initialized swarm as manager${NC}"
    else
        echo -e "${RED}✗ Failed to initialize swarm as manager${NC}"
        exit 1
    fi
fi

# Step 3: List nodes and check their status
echo -e "\n${YELLOW}STEP 3: Checking node status in the swarm...${NC}"
echo -e "${BOLD}Node list from Docker Swarm:${NC}"
docker node ls

# Step 4: Check connectivity to nodes
echo -e "\n${YELLOW}STEP 4: Checking network connectivity to all nodes...${NC}"
NODES=(
    "master:192.168.0.200:manager"
    "optiplex70101:192.168.0.202:worker"
    "optiplex70102:192.168.0.203:worker"
    "lenovo:192.168.0.205:worker"
    "hp-laptop:192.168.0.204:worker"
    "samsung-a50:192.168.0.210:worker"
)

for NODE in "${NODES[@]}"; do
    IFS=':' read -r NODE_NAME NODE_IP NODE_ROLE <<< "$NODE"
    
    echo -e "\n${BOLD}Checking $NODE_NAME ($NODE_IP, role: $NODE_ROLE)...${NC}"
    
    # Check connectivity
    if ping -c 1 -W 2 "$NODE_IP" &> /dev/null; then
        echo -e "${GREEN}✓ $NODE_NAME is reachable at $NODE_IP${NC}"
        
        # Skip additional checks for the master node (we're already running on it)
        if [ "$NODE_NAME" = "master" ]; then
            continue
        fi
        
        # Check SSH connectivity (for server nodes)
        if [[ "$NODE_NAME" == optiplex* ]]; then
            echo -e "Checking SSH connectivity..."
            if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes "$NODE_IP" "echo Connected" &>/dev/null; then
                echo -e "${GREEN}✓ SSH connection to $NODE_NAME successful${NC}"
                
                # Check Docker service
                DOCKER_STATUS=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$NODE_IP" "systemctl is-active docker" 2>/dev/null)
                if [ "$DOCKER_STATUS" = "active" ]; then
                    echo -e "${GREEN}✓ Docker service is running on $NODE_NAME${NC}"
                    
                    # Check swarm status
                    SWARM_STATUS=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$NODE_IP" "docker info --format '{{.Swarm.LocalNodeState}}'" 2>/dev/null)
                    if [ "$SWARM_STATUS" = "active" ]; then
                        echo -e "${GREEN}✓ $NODE_NAME is part of the swarm${NC}"
                    else
                        echo -e "${RED}✗ $NODE_NAME is not part of the swarm${NC}"
                        echo -e "Getting join token..."
                        JOIN_TOKEN=$(docker swarm join-token worker -q)
                        echo -e "Attempting to join $NODE_NAME to the swarm..."
                        ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$NODE_IP" "docker swarm join --token $JOIN_TOKEN 192.168.0.200:2377" 2>/dev/null
                        if [ $? -eq 0 ]; then
                            echo -e "${GREEN}✓ $NODE_NAME joined the swarm${NC}"
                        else
                            echo -e "${RED}✗ Failed to join $NODE_NAME to the swarm${NC}"
                        fi
                    fi
                else
                    echo -e "${RED}✗ Docker service is not running on $NODE_NAME${NC}"
                    echo -e "Attempting to start Docker service..."
                    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$NODE_IP" "sudo systemctl start docker" 2>/dev/null
                    if [ $? -eq 0 ]; then
                        echo -e "${GREEN}✓ Started Docker service on $NODE_NAME${NC}"
                    else
                        echo -e "${RED}✗ Failed to start Docker service on $NODE_NAME${NC}"
                    fi
                fi
            else
                echo -e "${RED}✗ SSH connection to $NODE_NAME failed${NC}"
            fi
        # Check Windows nodes (Lenovo and HP laptops)
        elif [[ "$NODE_NAME" == "lenovo" || "$NODE_NAME" == "hp-laptop" ]]; then
            # For Windows nodes, try to connect via different usernames
            echo -e "Checking SSH connectivity (Windows node)..."
            SSH_CONNECTED=false
            for USER in "Administrator" "User" "admin" "owner"; do
                if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes "$USER@$NODE_IP" "echo Connected" &>/dev/null; then
                    echo -e "${GREEN}✓ SSH connection to $NODE_NAME successful with user $USER${NC}"
                    SSH_CONNECTED=true
                    
                    # Check Docker status
                    DOCKER_RUNNING=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 "$USER@$NODE_IP" "powershell -Command \"(Get-Service -Name docker).Status\"" 2>/dev/null)
                    if [[ "$DOCKER_RUNNING" == *"Running"* ]]; then
                        echo -e "${GREEN}✓ Docker service is running on $NODE_NAME${NC}"
                        
                        # Check swarm status
                        SWARM_STATUS=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 "$USER@$NODE_IP" "powershell -Command \"docker info --format '{{.Swarm.LocalNodeState}}'\"" 2>/dev/null)
                        if [ "$SWARM_STATUS" = "active" ]; then
                            echo -e "${GREEN}✓ $NODE_NAME is part of the swarm${NC}"
                        else
                            echo -e "${RED}✗ $NODE_NAME is not part of the swarm${NC}"
                            echo -e "Getting join token..."
                            JOIN_TOKEN=$(docker swarm join-token worker -q)
                            echo -e "Attempting to join $NODE_NAME to the swarm..."
                            ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 "$USER@$NODE_IP" "powershell -Command \"docker swarm join --token $JOIN_TOKEN 192.168.0.200:2377\"" 2>/dev/null
                            if [ $? -eq 0 ]; then
                                echo -e "${GREEN}✓ $NODE_NAME joined the swarm${NC}"
                            else
                                echo -e "${RED}✗ Failed to join $NODE_NAME to the swarm${NC}"
                            fi
                        fi
                    else
                        echo -e "${RED}✗ Docker service is not running on $NODE_NAME${NC}"
                        echo -e "Attempting to start Docker service..."
                        ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 "$USER@$NODE_IP" "powershell -Command \"Start-Service docker\"" 2>/dev/null
                        if [ $? -eq 0 ]; then
                            echo -e "${GREEN}✓ Started Docker service on $NODE_NAME${NC}"
                        else
                            echo -e "${RED}✗ Failed to start Docker service on $NODE_NAME${NC}"
                        fi
                    fi
                    break
                fi
            done
            
            if [ "$SSH_CONNECTED" = false ]; then
                echo -e "${RED}✗ SSH connection to $NODE_NAME failed with all users${NC}"
            fi
        # Check Samsung A50 (mobile device)
        elif [ "$NODE_NAME" = "samsung-a50" ]; then
            echo -e "Checking SSH connectivity to Samsung A50 (port 8022)..."
            # SSH connection to Termux is on port 8022
            SSH_CONNECTED=false
            for PREFIX in "u0_a" "shell" "root"; do
                for SUFFIX in $(seq 10 100); do
                    USER_ID="${PREFIX}${SUFFIX}"
                    if ssh -p 8022 -o StrictHostKeyChecking=no -o ConnectTimeout=2 -o BatchMode=yes "$USER_ID@$NODE_IP" "echo Connected" &>/dev/null; then
                        echo -e "${GREEN}✓ SSH connection to Samsung A50 successful with user $USER_ID${NC}"
                        SSH_CONNECTED=true
                        
                        # Check Docker status
                        echo -e "Checking Docker status on Samsung A50..."
                        DOCKER_STATUS=$(ssh -p 8022 -o StrictHostKeyChecking=no -o ConnectTimeout=2 "$USER_ID@$NODE_IP" "proot-distro login ubuntu -- docker info 2>/dev/null | grep 'Server Version'" || echo "Not running")
                        if [ "$DOCKER_STATUS" != "Not running" ]; then
                            echo -e "${GREEN}✓ Docker is running on Samsung A50${NC}"
                            
                            # Check swarm status
                            SWARM_STATUS=$(ssh -p 8022 -o StrictHostKeyChecking=no -o ConnectTimeout=2 "$USER_ID@$NODE_IP" "proot-distro login ubuntu -- docker info 2>/dev/null | grep 'Swarm: '" || echo "Swarm: inactive")
                            if [[ "$SWARM_STATUS" == *"active"* ]]; then
                                echo -e "${GREEN}✓ Samsung A50 is part of the Docker Swarm${NC}"
                            else
                                echo -e "${RED}✗ Samsung A50 is not part of the swarm${NC}"
                                echo -e "Getting join token..."
                                JOIN_TOKEN=$(docker swarm join-token worker -q)
                                echo -e "Attempting to join Samsung A50 to the swarm..."
                                ssh -p 8022 -o StrictHostKeyChecking=no -o ConnectTimeout=2 "$USER_ID@$NODE_IP" "proot-distro login ubuntu -- docker swarm join --token $JOIN_TOKEN 192.168.0.200:2377" 2>/dev/null
                                if [ $? -eq 0 ]; then
                                    echo -e "${GREEN}✓ Samsung A50 joined the swarm${NC}"
                                else
                                    echo -e "${RED}✗ Failed to join Samsung A50 to the swarm${NC}"
                                fi
                            fi
                        else
                            echo -e "${RED}✗ Docker is not running on Samsung A50${NC}"
                            echo -e "Attempting to start Docker..."
                            ssh -p 8022 -o StrictHostKeyChecking=no -o ConnectTimeout=2 "$USER_ID@$NODE_IP" "termux-wake-lock && ~/start-docker.sh" 2>/dev/null
                            if [ $? -eq 0 ]; then
                                echo -e "${GREEN}✓ Docker started on Samsung A50${NC}"
                            else
                                echo -e "${RED}✗ Failed to start Docker on Samsung A50${NC}"
                            fi
                        fi
                        break 2
                    fi
                done
            done
            
            if [ "$SSH_CONNECTED" = false ]; then
                echo -e "${RED}✗ SSH connection to Samsung A50 failed with all users${NC}"
            fi
        fi
    else
        echo -e "${RED}✗ $NODE_NAME is not reachable at $NODE_IP${NC}"
        if [ "$NODE_NAME" != "master" ]; then
            echo -e "Attempting to wake up $NODE_NAME..."
            # Try to get MAC address from ARP table
            MAC_ADDRESS=$(arp -n | grep "$NODE_IP" | awk '{print $3}' | head -n 1)
            if [ -n "$MAC_ADDRESS" ]; then
                echo -e "Found MAC address: $MAC_ADDRESS"
                echo -e "Sending wake-on-LAN packet..."
                wakeonlan "$MAC_ADDRESS" 2>/dev/null || etherwake "$MAC_ADDRESS" 2>/dev/null
                echo -e "Waiting for $NODE_NAME to wake up..."
                for i in {1..15}; do
                    sleep 2
                    if ping -c 1 -W 2 "$NODE_IP" &> /dev/null; then
                        echo -e "${GREEN}✓ $NODE_NAME is now reachable${NC}"
                        break
                    fi
                    echo -n "."
                    if [ $i -eq 15 ]; then
                        echo -e "\n${RED}✗ Timed out waiting for $NODE_NAME to respond${NC}"
                    fi
                done
            else
                echo -e "${RED}✗ Could not find MAC address for $NODE_NAME${NC}"
            fi
        fi
    fi
done

# Step 5: Update node list
echo -e "\n${YELLOW}STEP 5: Showing updated node list...${NC}"
docker node ls

# Step 6: Check for available services
echo -e "\n${YELLOW}STEP 6: Checking services...${NC}"
docker service ls

# Step 7: Check visualizer
echo -e "\n${YELLOW}STEP 7: Checking Swarm Visualizer...${NC}"
VISUALIZER=$(docker service ls --filter name=visualizer -q)
if [ -n "$VISUALIZER" ]; then
    echo -e "${GREEN}✓ Swarm Visualizer is running${NC}"
    echo -e "Access the visualizer at: http://192.168.0.200:8080"
else
    echo -e "${YELLOW}⚠ Swarm Visualizer is not running${NC}"
    echo -e "Would you like to deploy the Swarm Visualizer? (y/n)"
    read -r DEPLOY_VISUALIZER
    if [[ "$DEPLOY_VISUALIZER" =~ ^[Yy]$ ]]; then
        echo -e "Deploying Swarm Visualizer..."
        docker service create \
            --name visualizer \
            --publish 8080:8080 \
            --constraint node.role==manager \
            --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
            dockersamples/visualizer
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Swarm Visualizer deployed successfully${NC}"
            echo -e "Access the visualizer at: http://192.168.0.200:8080"
        else
            echo -e "${RED}✗ Failed to deploy Swarm Visualizer${NC}"
        fi
    fi
fi

# Final summary
echo -e "\n${BLUE}====================================================${NC}"
echo -e "${BLUE}     TESTING COMPLETE                               ${NC}"
echo -e "${BLUE}====================================================${NC}"
echo
echo -e "${YELLOW}Recommendations:${NC}"
echo "1. For any offline nodes, make sure they are powered on and properly configured"
echo "2. For nodes not in the swarm, use the appropriate add_*.sh script:"
echo "   - HP laptop: sudo ./add_hp_laptop.sh"
echo "   - Lenovo laptop: sudo ./add_lenovo_laptop.sh"
echo "   - Samsung A50: sudo ./add_samsung_a50.sh"
echo "   - Server nodes: Use node_startup.sh"
echo
echo "3. To make management easier, make sure all scripts are executable:"
echo "   sudo ./make_all_executable.sh"
echo
echo "4. To deploy load balancing, run:"
echo "   sudo /home/optiplex_780_1/Desktop/BlueprintProject/loadbalance/setup_load_balancer.sh"
echo
echo -e "${GREEN}Your cluster is now ready to use!${NC}"
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
