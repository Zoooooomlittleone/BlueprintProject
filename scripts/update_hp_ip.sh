#!/bin/bash

# Update HP Laptop IP Address
# This script updates the IP address for the HP laptop in all configuration files

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}     UPDATE HP LAPTOP IP ADDRESS                    ${NC}"
echo -e "${BLUE}====================================================${NC}"
echo

# Get the script directory
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Show available IP addresses from the scan
echo -e "${YELLOW}Available devices on the network:${NC}"
echo -e "1. 192.168.0.91"
echo -e "2. 192.168.0.106"
echo -e "3. 192.168.0.116"
echo -e "4. 192.168.0.170"
echo -e "5. 192.168.0.204"
echo -e "6. Other (specify manually)"
echo -e "7. Disable HP laptop integration"

# Ask user which IP to use
echo
echo -e "Which IP address corresponds to your HP laptop?"
read -p "Enter a number (1-7): " CHOICE

case $CHOICE in
    1) NEW_IP="192.168.0.91" ;;
    2) NEW_IP="192.168.0.106" ;;
    3) NEW_IP="192.168.0.116" ;;
    4) NEW_IP="192.168.0.170" ;;
    5) NEW_IP="192.168.0.204" ;;
    6) 
        read -p "Enter the IP address for the HP laptop: " NEW_IP
        # Validate IP address format
        if ! [[ $NEW_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo -e "${RED}Invalid IP address format${NC}"
            exit 1
        fi
        ;;
    7) 
        echo -e "${YELLOW}Disabling HP laptop integration...${NC}"
        # Set a placeholder IP that won't be reached
        NEW_IP="192.168.0.254"
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

OLD_IP="192.168.0.206"
echo -e "${YELLOW}Updating HP laptop IP address from ${OLD_IP} to ${NEW_IP}...${NC}"

# Function to update IP in a file
update_ip() {
    local file=$1
    
    # Check if file exists
    if [ ! -f "$file" ]; then
        echo -e "${RED}File not found: $file${NC}"
        return 1
    fi
    
    # Create backup
    cp "$file" "${file}.bak"
    
    # Replace IP address
    sed -i "s/$OLD_IP/$NEW_IP/g" "$file"
    
    # Count replacements
    local count=$(grep -c "$NEW_IP" "$file")
    echo -e "${GREEN}✓ Updated $file ($count occurrences)${NC}"
}

# Update IP in all relevant files
FILES=(
    "$SCRIPT_DIR/node_startup.sh"
    "$SCRIPT_DIR/node_shutdown.sh"
    "$SCRIPT_DIR/add_hp_laptop.sh"
    "$SCRIPT_DIR/test_all_nodes.sh"
)

for file in "${FILES[@]}"; do
    update_ip "$file"
done

if [ "$CHOICE" -eq 7 ]; then
    echo -e "${YELLOW}HP laptop integration has been disabled.${NC}"
    echo -e "The scripts will still check for a device at ${NEW_IP}, but it won't interfere with other operations."
else
    # Verify the HP laptop is reachable at the new IP
    echo -e "\n${YELLOW}Verifying HP laptop is reachable at ${NEW_IP}...${NC}"
    if ping -c 1 -W 2 "$NEW_IP" &> /dev/null; then
        echo -e "${GREEN}✓ HP laptop is reachable at ${NEW_IP}${NC}"
        
        # Try SSH connection
        echo -e "Attempting SSH connection to verify it's the HP laptop..."
        SSH_SUCCESS=false
        for USER in "Administrator" "admin" "user" "hp-user"; do
            if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes "$USER@$NEW_IP" "echo Connected" &>/dev/null; then
                echo -e "${GREEN}✓ SSH connection successful with user: $USER${NC}"
                SSH_SUCCESS=true
                break
            fi
        done
        
        if [ "$SSH_SUCCESS" = false ]; then
            echo -e "${YELLOW}⚠ Could not establish SSH connection to ${NEW_IP}${NC}"
            echo -e "This might still be your HP laptop, but SSH access is not configured."
        fi
    else
        echo -e "${RED}✗ No device found at ${NEW_IP}${NC}"
        echo -e "${YELLOW}⚠ Configuration updated, but the HP laptop appears to be offline${NC}"
    fi
fi

echo -e "\n${BLUE}====================================================${NC}"
echo -e "${GREEN}     CONFIGURATION UPDATED SUCCESSFULLY           ${NC}"
echo -e "${BLUE}====================================================${NC}"
echo
echo -e "All scripts have been updated to use ${NEW_IP} for the HP laptop."
echo -e "Backups of the original files were created with .bak extension."
echo
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Run the 'Make All Scripts Executable' shortcut to ensure all scripts are executable"
echo -e "2. Run the 'Test All Nodes' shortcut to verify node connectivity"
echo -e "3. If the HP laptop is online, run 'Add HP Laptop to Swarm' to add it to the cluster"
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
