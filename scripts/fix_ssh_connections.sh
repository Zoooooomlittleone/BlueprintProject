#!/bin/bash
# Created on: $(date)
# Author: System Administrator
# Fix SSH Connections between Swarm Nodes
# This script sets up passwordless SSH authentication between the master node and worker nodes

# Set colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}    DOCKER SWARM SSH CONNECTION FIX    ${NC}"
echo -e "${BLUE}=====================================================${NC}"

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}This script must be run with sudo privileges${NC}"
  exit 1
fi

# Node information
declare -A NODE_IPS
NODE_IPS=(
    ["optiplex_780_1"]="192.168.0.200"
    ["optiplex_780_2"]="192.168.0.201"
    ["optiplex70101"]="192.168.0.202"
    ["optiplex70102"]="192.168.0.203"
    ["laptopnode"]="192.168.0.204"
    ["docker-desktop"]="192.168.0.205"
)

# Function to setup SSH key authentication
setup_ssh_keys() {
    echo -e "${YELLOW}Setting up SSH key authentication...${NC}"
    
    # Check if SSH key exists, if not create one
    if [ ! -f /home/optiplex_780_1/.ssh/id_rsa ]; then
        echo -e "${YELLOW}Generating SSH key pair...${NC}"
        sudo -u optiplex_780_1 ssh-keygen -t rsa -N "" -f /home/optiplex_780_1/.ssh/id_rsa
    fi
    
    # Setup SSH config to avoid strict host key checking
    if [ ! -f /home/optiplex_780_1/.ssh/config ]; then
        echo -e "${YELLOW}Creating SSH config...${NC}"
        sudo -u optiplex_780_1 bash -c 'cat > /home/optiplex_780_1/.ssh/config << EOF
Host 192.168.0.*
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
EOF'
        chmod 600 /home/optiplex_780_1/.ssh/config
    fi
}

# Function to add host entries
update_hosts_file() {
    echo -e "${YELLOW}Updating /etc/hosts file...${NC}"
    
    # Backup hosts file
    cp /etc/hosts /etc/hosts.bak
    
    # Add or update entries
    for node in "${!NODE_IPS[@]}"; do
        ip="${NODE_IPS[$node]}"
        
        # Check if entry exists
        if grep -q "$ip" /etc/hosts; then
            # Update existing entry
            sed -i "s/^$ip.*/$ip $node/" /etc/hosts
        else
            # Add new entry
            echo "$ip $node" >> /etc/hosts
        fi
    done
    
    echo -e "${GREEN}✓ Hosts file updated${NC}"
}

# Function to test SSH connectivity
test_ssh_connection() {
    local node=$1
    local ip=$2
    
    echo -e "${YELLOW}Testing SSH connection to $node ($ip)...${NC}"
    
    # Try to connect with StrictHostKeyChecking=no
    if sudo -u optiplex_780_1 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 optiplex_780_1@$ip 'echo "SSH connection successful"' &>/dev/null; then
        echo -e "${GREEN}✓ SSH connection to $node successful${NC}"
        return 0
    else
        echo -e "${RED}✗ SSH connection to $node failed${NC}"
        return 1
    fi
}

# Function to copy SSH key to remote node
copy_ssh_key() {
    local node=$1
    local ip=$2
    
    echo -e "${YELLOW}Copying SSH key to $node ($ip)...${NC}"
    
    # Prompt for password
    echo -e "${YELLOW}Enter password for user optiplex_780_1 on $node:${NC}"
    
    # Use sshpass if available
    if command -v sshpass &> /dev/null; then
        read -s password
        echo ""
        
        if sshpass -p "$password" ssh-copy-id -o StrictHostKeyChecking=no optiplex_780_1@$ip; then
            echo -e "${GREEN}✓ SSH key copied to $node${NC}"
            return 0
        else
            echo -e "${RED}✗ Failed to copy SSH key to $node${NC}"
            return 1
        fi
    else
        # Fallback to manual copy-id
        if sudo -u optiplex_780_1 ssh-copy-id -o StrictHostKeyChecking=no optiplex_780_1@$ip; then
            echo -e "${GREEN}✓ SSH key copied to $node${NC}"
            return 0
        else
            echo -e "${RED}✗ Failed to copy SSH key to $node${NC}"
            return 1
        fi
    fi
}

# Function to fix SSH connections
fix_ssh_connections() {
    echo -e "${YELLOW}Fixing SSH connections to all nodes...${NC}"
    
    # Setup local SSH keys
    setup_ssh_keys
    
    # Update hosts file
    update_hosts_file
    
    # Set correct permissions for .ssh directory
    chown -R optiplex_780_1:optiplex_780_1 /home/optiplex_780_1/.ssh
    chmod 700 /home/optiplex_780_1/.ssh
    chmod 600 /home/optiplex_780_1/.ssh/id_rsa
    chmod 644 /home/optiplex_780_1/.ssh/id_rsa.pub
    
    # Test and fix connections to each node
    for node in "${!NODE_IPS[@]}"; do
        # Skip localhost
        if [ "$node" == "optiplex_780_1" ]; then
            continue
        fi
        
        ip="${NODE_IPS[$node]}"
        
        # Test connection
        if ! test_ssh_connection "$node" "$ip"; then
            echo -e "${YELLOW}Will attempt to fix SSH connection to $node...${NC}"
            copy_ssh_key "$node" "$ip"
        fi
    done
}

# Function to validate connections
validate_connections() {
    echo -e "${YELLOW}Validating SSH connections to all nodes...${NC}"
    
    local all_successful=true
    
    for node in "${!NODE_IPS[@]}"; do
        # Skip localhost
        if [ "$node" == "optiplex_780_1" ]; then
            continue
        fi
        
        ip="${NODE_IPS[$node]}"
        
        # Test connection
        if ! test_ssh_connection "$node" "$ip"; then
            all_successful=false
        fi
    done
    
    if [ "$all_successful" = true ]; then
        echo -e "${GREEN}✓ All SSH connections are working correctly${NC}"
        return 0
    else
        echo -e "${RED}✗ Some SSH connections are still not working${NC}"
        return 1
    fi
}

# Main function
main() {
    echo -e "${YELLOW}Starting SSH connection fixes...${NC}"
    
    # Fix SSH connections
    fix_ssh_connections
    
    # Validate connections
    validate_connections
    
    echo -e "${BLUE}=====================================================${NC}"
    echo -e "${GREEN}    SSH CONNECTION FIX COMPLETED    ${NC}"
    echo -e "${BLUE}=====================================================${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "1. Run scripts/collect_node_specs.sh to gather node information"
    echo -e "2. Run scripts/advanced_load_balancing.sh to optimize load balancing"
    echo -e "3. Update the BlueprintProject documentation with the latest information"
    echo ""
    echo -e "${BLUE}=====================================================${NC}"
}

# Run main function
main
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
