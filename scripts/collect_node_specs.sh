#!/bin/bash
# Collect hardware and software specifications from all nodes in the swarm

# Add color support
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=================================================${NC}"
echo -e "${GREEN}    COLLECTING NODE SPECIFICATIONS    ${NC}"
echo -e "${BLUE}=================================================${NC}"

# Base directory for specs
SPECS_DIR="/home/optiplex_780_1/Desktop/BlueprintProject/node_specs"
mkdir -p $SPECS_DIR

# Function to collect node specifications
collect_node_specs() {
    local NODE=$1
    local IP=$2
    local SPEC_FILE="$SPECS_DIR/${NODE}_specs.md"
    
    echo -e "${YELLOW}Collecting specifications for node: $NODE ($IP)${NC}"
    
    # SSH to node and collect information
    ssh optiplex_780_1@$IP "
        echo '# $NODE Specifications' > specs.txt
        echo '' >> specs.txt
        echo '## Hardware' >> specs.txt
        echo '### System Information' >> specs.txt
        echo '```' >> specs.txt
        hostnamectl >> specs.txt
        echo '```' >> specs.txt
        
        echo '### CPU' >> specs.txt
        echo '```' >> specs.txt
        lscpu >> specs.txt
        echo '```' >> specs.txt
        
        echo '### Memory' >> specs.txt
        echo '```' >> specs.txt
        free -h >> specs.txt
        echo '```' >> specs.txt
        
        echo '### Disk' >> specs.txt
        echo '```' >> specs.txt
        df -h >> specs.txt
        lsblk >> specs.txt
        echo '```' >> specs.txt
        
        echo '### Network' >> specs.txt
        echo '```' >> specs.txt
        ip addr >> specs.txt
        echo '```' >> specs.txt
        
        echo '## Software' >> specs.txt
        echo '### OS' >> specs.txt
        echo '```' >> specs.txt
        cat /etc/os-release >> specs.txt
        echo '```' >> specs.txt
        
        echo '### Kernel' >> specs.txt
        echo '```' >> specs.txt
        uname -a >> specs.txt
        echo '```' >> specs.txt
        
        echo '### Docker' >> specs.txt
        echo '```' >> specs.txt
        docker version >> specs.txt
        docker info >> specs.txt
        echo '```' >> specs.txt
        
        echo '### Installed Packages' >> specs.txt
        echo '```' >> specs.txt
        if command -v apt &> /dev/null; then
            apt list --installed | grep -E 'docker|containerd|kubernetes|swarm'
        elif command -v yum &> /dev/null; then
            yum list installed | grep -E 'docker|containerd|kubernetes|swarm'
        else
            echo 'Package manager not found'
        fi >> specs.txt
        echo '```' >> specs.txt
    " || { echo -e "${RED}Failed to connect to $NODE ($IP)${NC}"; return 1; }
    
    # Retrieve the specs file
    scp optiplex_780_1@$IP:specs.txt $SPEC_FILE || { echo -e "${RED}Failed to retrieve specs from $NODE ($IP)${NC}"; return 1; }
    ssh optiplex_780_1@$IP "rm specs.txt"
    
    echo -e "${GREEN}Specifications for $NODE saved to $SPEC_FILE${NC}"
    return 0
}

# First, collect specs for master node (this machine)
echo -e "${YELLOW}Collecting specifications for master node (localhost)${NC}"
MASTER_SPEC_FILE="$SPECS_DIR/master_specs.md"

# Collect master node specs locally
{
    echo '# Master Node Specifications'
    echo ''
    echo '## Hardware'
    echo '### System Information'
    echo '```'
    hostnamectl
    echo '```'
    
    echo '### CPU'
    echo '```'
    lscpu
    echo '```'
    
    echo '### Memory'
    echo '```'
    free -h
    echo '```'
    
    echo '### Disk'
    echo '```'
    df -h
    lsblk
    echo '```'
    
    echo '### Network'
    echo '```'
    ip addr
    echo '```'
    
    echo '## Software'
    echo '### OS'
    echo '```'
    cat /etc/os-release
    echo '```'
    
    echo '### Kernel'
    echo '```'
    uname -a
    echo '```'
    
    echo '### Docker'
    echo '```'
    docker version
    docker info
    echo '```'
    
    echo '### Installed Packages'
    echo '```'
    if command -v apt &> /dev/null; then
        apt list --installed | grep -E 'docker|containerd|kubernetes|swarm'
    elif command -v yum &> /dev/null; then
        yum list installed | grep -E 'docker|containerd|kubernetes|swarm'
    else
        echo 'Package manager not found'
    fi
    echo '```'
} > $MASTER_SPEC_FILE

echo -e "${GREEN}Specifications for master node saved to $MASTER_SPEC_FILE${NC}"

# Now collect specs for each worker node
echo -e "${YELLOW}Collecting specifications for worker nodes...${NC}"

# List of nodes and their IPs
declare -A NODE_IPS
NODE_IPS=(
    ["optiplex_780_2"]="192.168.0.201"
    ["optiplex70101"]="192.168.0.202"
    ["optiplex70102"]="192.168.0.203"
    ["laptopnode"]="192.168.0.204"
    ["docker-desktop"]="192.168.0.205"
)

# Collect specs for each node
for node in "${!NODE_IPS[@]}"; do
    collect_node_specs "$node" "${NODE_IPS[$node]}" || echo -e "${RED}Failed to collect specifications for $node${NC}"
done

# Create a summary file with hardware specs for all nodes
SUMMARY_FILE="$SPECS_DIR/cluster_hardware_summary.md"
echo -e "${YELLOW}Creating hardware summary for all nodes...${NC}"

{
    echo "# Docker Swarm Cluster Hardware Summary"
    echo ""
    echo "Last Updated: $(date "+%Y-%m-%d %H:%M:%S")"
    echo ""
    echo "## Master Node (optiplex_780_1)"
    echo ""
    
    if [ -f "$SPECS_DIR/master_specs.md" ]; then
        # Extract CPU info
        echo "### CPU"
        grep -A3 "Model name" "$SPECS_DIR/master_specs.md" | grep -v "```"
        
        # Extract Memory info
        echo ""
        echo "### Memory"
        grep -A3 "Mem:" "$SPECS_DIR/master_specs.md" | grep -v "```"
        
        # Extract Disk info
        echo ""
        echo "### Disk"
        grep -A3 "Filesystem" "$SPECS_DIR/master_specs.md" | grep -v "```" | head -4
    else
        echo "Information not available"
    fi
    
    # Add worker nodes
    for node in "${!NODE_IPS[@]}"; do
        echo ""
        echo "## $node"
        echo ""
        
        if [ -f "$SPECS_DIR/${node}_specs.md" ]; then
            # Extract CPU info
            echo "### CPU"
            grep -A3 "Model name" "$SPECS_DIR/${node}_specs.md" | grep -v "```"
            
            # Extract Memory info
            echo ""
            echo "### Memory"
            grep -A3 "Mem:" "$SPECS_DIR/${node}_specs.md" | grep -v "```"
            
            # Extract Disk info
            echo ""
            echo "### Disk"
            grep -A3 "Filesystem" "$SPECS_DIR/${node}_specs.md" | grep -v "```" | head -4
        else
            echo "Information not available"
        fi
    done
} > $SUMMARY_FILE

echo -e "${GREEN}Hardware summary created: $SUMMARY_FILE${NC}"

# Create a full cluster blueprint document
BLUEPRINT_FILE="/home/optiplex_780_1/Desktop/BlueprintProject/CLUSTER_BLUEPRINT.md"
echo -e "${YELLOW}Creating comprehensive cluster blueprint...${NC}"

{
    echo "# Docker Swarm Cluster Blueprint"
    echo ""
    echo "Last Updated: $(date "+%Y-%m-%d %H:%M:%S")"
    echo ""
    echo "## Overview"
    echo ""
    echo "This blueprint provides a comprehensive overview of our Docker Swarm cluster,"
    echo "including node specifications, network configuration, storage, and operational procedures."
    echo ""
    echo "## Cluster Architecture"
    echo ""
    echo "### Master Node"
    echo "- **Hostname**: master (optiplex_780_1)"
    echo "- **IP Address**: 192.168.0.200"
    echo "- **Role**: Manager (Leader)"
    echo ""
    echo "### Worker Nodes"
    echo "- **optiplex_780_2**"
    echo "  - **IP Address**: 192.168.0.201"
    echo "  - **Role**: Worker"
    echo "- **optiplex70101**"
    echo "  - **IP Address**: 192.168.0.202"
    echo "  - **Role**: Worker"
    echo "- **optiplex70102**"
    echo "  - **IP Address**: 192.168.0.203"
    echo "  - **Role**: Worker"
    echo "- **laptopnode** (HP Laptop)"
    echo "  - **IP Address**: 192.168.0.204"
    echo "  - **Role**: Worker"
    echo "- **docker-desktop** (Lenovo Laptop)"
    echo "  - **IP Address**: 192.168.0.205"
    echo "  - **Role**: Worker"
    echo ""
    echo "## Network Configuration"
    echo ""
    echo "The cluster operates on network 192.168.0.0/24 with dedicated IP addresses for each node."
    echo "Internal container networking uses overlay networks for multi-host communication."
    echo ""
    echo "## Storage Configuration"
    echo ""
    echo "- **Local Storage**: Each node has its own local storage"
    echo "- **Shared Storage**: Docker volumes are used for persistent data"
    echo "- **Backup Location**: /home/optiplex_780_1/Desktop/BlueprintProject/backups"
    echo ""
    echo "## Operational Procedures"
    echo ""
    echo "### Adding a New Node"
    echo "```bash"
    echo "# On master node, get join token"
    echo "docker swarm join-token worker"
    echo ""
    echo "# On new node, run the join command"
    echo "docker swarm join --token SWMTKN-xxxx 192.168.0.200:2377"
    echo "```"
    echo ""
    echo "### Synchronized Shutdown"
    echo "To shut down the entire cluster in a synchronized manner:"
    echo "```bash"
    echo "/home/optiplex_780_1/Desktop/BlueprintProject/scripts/node_shutdown.sh"
    echo "```"
    echo ""
    echo "### Automated Health Checks"
    echo "The cluster performs automated health checks every 5 minutes."
    echo ""
    echo "### Load Balancing"
    echo "Load balancing across nodes is handled automatically by Docker Swarm's built-in load balancer."
    echo ""
    echo "## Recovery Procedures"
    echo ""
    echo "### Master Node Failure"
    echo "In case of master node failure:"
    echo "1. Restore the master node from backup"
    echo "2. Reinitialize the swarm: `docker swarm init --advertise-addr 192.168.0.200`"
    echo "3. Generate new join tokens and have worker nodes rejoin"
    echo ""
    echo "### Worker Node Failure"
    echo "In case of worker node failure:"
    echo "1. Remove the node from the swarm: `docker node rm <node-id>`"
    echo "2. Repair the node and have it rejoin the swarm"
    echo ""
    echo "## Security Measures"
    echo ""
    echo "- TLS encryption for all swarm communications"
    echo "- Node authentication via tokens"
    echo "- Regular security patches"
    echo ""
    echo "## Backup Strategy"
    echo ""
    echo "- Daily automated backups of all volumes"
    echo "- Weekly full cluster state backup"
    echo "- Backups stored in `/home/optiplex_780_1/Desktop/BlueprintProject/backups`"
    echo ""
    echo "## Performance Monitoring"
    echo ""
    echo "The cluster uses Prometheus and Grafana for monitoring:"
    echo "- Prometheus endpoint: http://master:9090"
    echo "- Grafana dashboard: http://master:3000"
    echo ""
    echo "## Detailed Node Specifications"
    echo ""
    echo "Detailed hardware and software specifications for each node are stored in the `node_specs` directory."
} > $BLUEPRINT_FILE

echo -e "${GREEN}Comprehensive cluster blueprint created: $BLUEPRINT_FILE${NC}"

# Create a desktop shortcut
echo -e "${YELLOW}Creating desktop shortcut...${NC}"
cat > "/home/optiplex_780_1/Desktop/Collect_Node_Specs.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Collect Node Specs
Comment=Collect hardware and software specifications from all nodes
Exec=bash -c 'cd /home/optiplex_780_1/Desktop/BlueprintProject/scripts && ./collect_node_specs.sh; read -p "Press Enter to close..."'
Icon=utilities-terminal
Terminal=true
StartupNotify=true
EOF

chmod +x "/home/optiplex_780_1/Desktop/Collect_Node_Specs.desktop"
chmod +x "/home/optiplex_780_1/Desktop/BlueprintProject/scripts/collect_node_specs.sh"

echo -e "${BLUE}=================================================${NC}"
echo -e "${GREEN}    NODE SPECIFICATIONS COLLECTION COMPLETE    ${NC}"
echo -e "${BLUE}=================================================${NC}"
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
