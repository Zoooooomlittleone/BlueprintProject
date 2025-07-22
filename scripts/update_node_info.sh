#!/bin/bash
# File: /home/optiplex_780_1/Desktop/BlueprintProject/scripts/update_node_info.sh

# Add color support
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=================================================${NC}"
echo -e "${GREEN}    UPDATING NODE INFORMATION AND ADDING NEW NODE   ${NC}"
echo -e "${BLUE}=================================================${NC}"

# Base directory
BASE_DIR="/home/optiplex_780_1/Desktop/BlueprintProject"

# Find all script files and configuration files
echo -e "${YELLOW}Finding all configuration files...${NC}"
FILES=$(find $BASE_DIR -type f -name "*.sh" -o -name "*.yml" -o -name "*.md" -o -name "*.ps1")

# Update IP addresses for optiplex70101 and optiplex70102
echo -e "${YELLOW}Updating IP addresses for existing nodes...${NC}"
for file in $FILES; do
    # Update optiplex70101 IP
    if grep -q "optiplex70101.*192.168.0.201" "$file"; then
        echo "Updating optiplex70101 IP in $file"
        sed -i 's/optiplex70101.*192.168.0.201/optiplex70101 - 192.168.0.202/g' "$file"
    fi
    
    # Update optiplex70102 IP
    if grep -q "optiplex70102.*192.168.0.202" "$file"; then
        echo "Updating optiplex70102 IP in $file"
        sed -i 's/optiplex70102.*192.168.0.202/optiplex70102 - 192.168.0.203/g' "$file"
    fi
done

# Create script to add optiplex_780_2
echo -e "${YELLOW}Creating script to add optiplex_780_2...${NC}"

cat > "$BASE_DIR/scripts/add_optiplex_780_2.sh" << 'EOF'
#!/bin/bash
# Script to add optiplex_780_2 to the Docker Swarm

# Add color support
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=================================================${NC}"
echo -e "${GREEN}    ADDING OPTIPLEX_780_2 TO DOCKER SWARM CLUSTER   ${NC}"
echo -e "${BLUE}=================================================${NC}"

# Node information
NODE_HOSTNAME="optiplex_780_2"
NODE_IP="192.168.0.201"

echo -e "${YELLOW}Step 1: Getting swarm join token${NC}"
JOIN_TOKEN=$(docker swarm join-token worker -q)

if [ -z "$JOIN_TOKEN" ]; then
    echo -e "${RED}Failed to get join token. Is this node a swarm manager?${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 2: Connecting to $NODE_HOSTNAME ($NODE_IP) to join the swarm${NC}"
ssh optiplex_780_1@$NODE_IP "docker swarm leave --force 2>/dev/null; docker swarm join --token $JOIN_TOKEN 192.168.0.200:2377"

# Check if the node was successfully added
echo -e "${YELLOW}Step 3: Verifying node was added${NC}"
if docker node ls | grep -q $NODE_HOSTNAME; then
    echo -e "${GREEN}Node $NODE_HOSTNAME successfully added to the swarm!${NC}"
    
    # Get the node ID
    NODE_ID=$(docker node ls --filter "name=$NODE_HOSTNAME" --format "{{.ID}}")
    
    echo -e "${YELLOW}Step 4: Adding labels to node for persistence${NC}"
    docker node update --label-add node.type=compute --label-add node.location=local --label-add node.persistent=true $NODE_ID
    
    echo -e "${GREEN}Node $NODE_HOSTNAME has been labeled for persistence${NC}"
    echo -e "${GREEN}Node setup complete!${NC}"
else
    echo -e "${RED}Failed to add node $NODE_HOSTNAME to the swarm${NC}"
    exit 1
fi

EOF

chmod +x "$BASE_DIR/scripts/add_optiplex_780_2.sh"

# Update node_shutdown.sh script to include optiplex_780_2
if [ -f "$BASE_DIR/scripts/node_shutdown.sh" ]; then
    echo -e "${YELLOW}Updating node_shutdown.sh to include optiplex_780_2...${NC}"
    
    # Check if optiplex_780_2 is already in the file
    if ! grep -q "optiplex_780_2" "$BASE_DIR/scripts/node_shutdown.sh"; then
        # Find the pattern for case statement for nodes
        if grep -q "case.*node.*in" "$BASE_DIR/scripts/node_shutdown.sh"; then
            # Add optiplex_780_2 to the case statement
            sed -i '/case.*node.*in/a \        "optiplex_780_2")\n            NODE_IP="192.168.0.201" # Dell Optiplex 780_2\n            ;;' "$BASE_DIR/scripts/node_shutdown.sh"
        fi
    fi
fi

# Update node_startup.sh script to include optiplex_780_2
if [ -f "$BASE_DIR/scripts/node_startup.sh" ]; then
    echo -e "${YELLOW}Updating node_startup.sh to include optiplex_780_2...${NC}"
    
    # Check if optiplex_780_2 is already in the file
    if ! grep -q "optiplex_780_2" "$BASE_DIR/scripts/node_startup.sh"; then
        # Find the pattern for case statement for nodes
        if grep -q "case.*node.*in" "$BASE_DIR/scripts/node_startup.sh"; then
            # Add optiplex_780_2 to the case statement
            sed -i '/case.*node.*in/a \        "optiplex_780_2")\n            NODE_IP="192.168.0.201" # Dell Optiplex 780_2\n            ;;' "$BASE_DIR/scripts/node_startup.sh"
        fi
    fi
fi

# Create a desktop shortcut for optiplex_780_2
echo -e "${YELLOW}Creating desktop shortcut for optiplex_780_2...${NC}"

cat > "/home/optiplex_780_1/Desktop/Add_Optiplex_780_2.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Add Optiplex 780_2
Comment=Add Optiplex 780_2 to Docker Swarm
Exec=bash -c 'cd /home/optiplex_780_1/Desktop/BlueprintProject/scripts && ./add_optiplex_780_2.sh; read -p "Press Enter to close..."'
Icon=utilities-terminal
Terminal=true
StartupNotify=true
EOF

chmod +x "/home/optiplex_780_1/Desktop/Add_Optiplex_780_2.desktop"

# Run the script to add optiplex_780_2
echo -e "${GREEN}Now running the script to add optiplex_780_2 to the swarm...${NC}"
# Check if the node is already in the swarm
if docker node ls | grep -q "optiplex_780_2"; then
    echo -e "${YELLOW}Node optiplex_780_2 is already in the swarm. Skipping addition.${NC}"
else
    bash "$BASE_DIR/scripts/add_optiplex_780_2.sh"
fi

echo -e "${BLUE}=================================================${NC}"
echo -e "${GREEN}    NODE INFORMATION UPDATE COMPLETE    ${NC}"
echo -e "${BLUE}=================================================${NC}"
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
