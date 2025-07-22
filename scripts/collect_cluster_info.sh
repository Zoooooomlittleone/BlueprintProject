#!/bin/bash

# Cluster Information Collection Script
# This script gathers all information about the Docker Swarm cluster nodes and configuration

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_DIR="/home/optiplex_780_1/Desktop/BlueprintProject/data"
REPORT_FILE="$OUTPUT_DIR/cluster_report_$TIMESTAMP.md"

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}     DOCKER SWARM CLUSTER INFORMATION COLLECTOR     ${NC}"
echo -e "${BLUE}====================================================${NC}"
echo

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Initialize report file
cat > "$REPORT_FILE" << EOL
# Docker Swarm Cluster Comprehensive Report
Generated on: $(date)

## 1. SYSTEM OVERVIEW

EOL

echo -e "${YELLOW}Collecting system information...${NC}"

# Check if Docker is running
if systemctl is-active --quiet docker; then
    echo -e "${GREEN}✓ Docker service is running${NC}"
    echo "- Docker service is active and running" >> "$REPORT_FILE"
else
    echo -e "${RED}✗ Docker service is not running${NC}"
    echo "- Docker service is NOT running" >> "$REPORT_FILE"
    systemctl start docker
    echo "  - Attempted to start Docker service" >> "$REPORT_FILE"
fi

# Get Docker version
echo "### Docker Version" >> "$REPORT_FILE"
docker_version=$(docker version --format '{{.Server.Version}}')
echo "Server version: $docker_version" >> "$REPORT_FILE"
echo "Client version: $(docker version --format '{{.Client.Version}}')" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Check swarm status
echo "### Swarm Status" >> "$REPORT_FILE"
SWARM_STATUS=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)
if [ "$SWARM_STATUS" = "active" ]; then
    NODE_ROLE=$(docker info --format '{{.Swarm.ControlAvailable}}')
    if [ "$NODE_ROLE" = "true" ]; then
        echo -e "${GREEN}✓ Node is active as a swarm manager${NC}"
        echo "- Node is active as a swarm manager" >> "$REPORT_FILE"
        
        # Get swarm details
        echo "#### Swarm Details" >> "$REPORT_FILE"
        echo "\`\`\`" >> "$REPORT_FILE"
        docker info --format '{{.Swarm}}' >> "$REPORT_FILE"
        echo "\`\`\`" >> "$REPORT_FILE"
    else
        echo -e "${YELLOW}✗ Node is in swarm but not as manager${NC}"
        echo "- Node is in swarm but not as a manager" >> "$REPORT_FILE"
    fi
else
    echo -e "${RED}✗ Node is not part of Docker swarm${NC}"
    echo "- Node is not part of Docker swarm" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"

# Get node status
echo -e "${YELLOW}Collecting node information...${NC}"
echo "## 2. NODE INVENTORY" >> "$REPORT_FILE"

if [ "$SWARM_STATUS" = "active" ] && [ "$NODE_ROLE" = "true" ]; then
    # Get detailed node information
    echo "### Current Node List" >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
    docker node ls >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
    
    echo "### Detailed Node Information" >> "$REPORT_FILE"
    
    # For each node
    for NODE_ID in $(docker node ls -q); do
        NODE_INFO=$(docker node inspect "$NODE_ID" --format '{{.Description.Hostname}} ({{.ID}} - {{.Status.State}})')
        echo "#### $NODE_INFO" >> "$REPORT_FILE"
        echo "\`\`\`" >> "$REPORT_FILE"
        docker node inspect "$NODE_ID" --format '{{json .}}' | python3 -m json.tool >> "$REPORT_FILE"
        echo "\`\`\`" >> "$REPORT_FILE"
        
        # Add node labels
        echo "##### Labels" >> "$REPORT_FILE"
        LABELS=$(docker node inspect "$NODE_ID" --format '{{range $k, $v := .Spec.Labels}}{{$k}}={{$v}} {{end}}')
        if [ -z "$LABELS" ]; then
            echo "No labels configured" >> "$REPORT_FILE"
        else
            echo "- $LABELS" >> "$REPORT_FILE"
        fi
        
        echo "" >> "$REPORT_FILE"
    done
else
    echo "No node information available - not a swarm manager" >> "$REPORT_FILE"
fi

# Get service status
echo -e "${YELLOW}Collecting service information...${NC}"
echo "## 3. SERVICE INVENTORY" >> "$REPORT_FILE"

if [ "$SWARM_STATUS" = "active" ] && [ "$NODE_ROLE" = "true" ]; then
    # Get service list
    SERVICE_COUNT=$(docker service ls | wc -l)
    if [ "$SERVICE_COUNT" -gt 1 ]; then  # Account for header line
        echo "### Current Services" >> "$REPORT_FILE"
        echo "\`\`\`" >> "$REPORT_FILE"
        docker service ls >> "$REPORT_FILE"
        echo "\`\`\`" >> "$REPORT_FILE"
        
        echo "### Detailed Service Information" >> "$REPORT_FILE"
        
        # For each service
        for SERVICE_ID in $(docker service ls -q); do
            SERVICE_NAME=$(docker service inspect "$SERVICE_ID" --format '{{.Spec.Name}}')
            echo "#### $SERVICE_NAME" >> "$REPORT_FILE"
            echo "\`\`\`" >> "$REPORT_FILE"
            docker service inspect "$SERVICE_ID" --format '{{json .}}' | python3 -m json.tool >> "$REPORT_FILE"
            echo "\`\`\`" >> "$REPORT_FILE"
            
            # Service tasks
            echo "##### Tasks" >> "$REPORT_FILE"
            echo "\`\`\`" >> "$REPORT_FILE"
            docker service ps "$SERVICE_ID" >> "$REPORT_FILE"
            echo "\`\`\`" >> "$REPORT_FILE"
            
            echo "" >> "$REPORT_FILE"
        done
    else
        echo "No services deployed" >> "$REPORT_FILE"
    fi
else
    echo "No service information available - not a swarm manager" >> "$REPORT_FILE"
fi

# Get network status
echo -e "${YELLOW}Collecting network information...${NC}"
echo "## 4. NETWORK INVENTORY" >> "$REPORT_FILE"

# Get networks
echo "### Docker Networks" >> "$REPORT_FILE"
echo "\`\`\`" >> "$REPORT_FILE"
docker network ls >> "$REPORT_FILE"
echo "\`\`\`" >> "$REPORT_FILE"

echo "### Overlay Networks" >> "$REPORT_FILE"
OVERLAY_COUNT=$(docker network ls --filter driver=overlay | wc -l)
if [ "$OVERLAY_COUNT" -gt 1 ]; then  # Account for header line
    echo "\`\`\`" >> "$REPORT_FILE"
    docker network ls --filter driver=overlay >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
    
    # For each overlay network
    for NETWORK_ID in $(docker network ls --filter driver=overlay -q); do
        NETWORK_NAME=$(docker network inspect "$NETWORK_ID" --format '{{.Name}}')
        echo "#### $NETWORK_NAME" >> "$REPORT_FILE"
        echo "\`\`\`" >> "$REPORT_FILE"
        docker network inspect "$NETWORK_ID" --format '{{json .}}' | python3 -m json.tool >> "$REPORT_FILE"
        echo "\`\`\`" >> "$REPORT_FILE"
    done
else
    echo "No overlay networks configured" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"

# Collect system information
echo -e "${YELLOW}Collecting system configuration information...${NC}"
echo "## 5. SYSTEM CONFIGURATION" >> "$REPORT_FILE"

# System information
echo "### Host Information" >> "$REPORT_FILE"
echo "\`\`\`" >> "$REPORT_FILE"
uname -a >> "$REPORT_FILE"
echo "\`\`\`" >> "$REPORT_FILE"

echo "### CPU Information" >> "$REPORT_FILE"
echo "\`\`\`" >> "$REPORT_FILE"
lscpu | grep -E 'Model name|Socket|Core|Thread|CPU MHz' >> "$REPORT_FILE"
echo "\`\`\`" >> "$REPORT_FILE"

echo "### Memory Information" >> "$REPORT_FILE"
echo "\`\`\`" >> "$REPORT_FILE"
free -h >> "$REPORT_FILE"
echo "\`\`\`" >> "$REPORT_FILE"

echo "### Disk Information" >> "$REPORT_FILE"
echo "\`\`\`" >> "$REPORT_FILE"
df -h | grep -v '/snap/' >> "$REPORT_FILE"
echo "\`\`\`" >> "$REPORT_FILE"

echo "### Network Interfaces" >> "$REPORT_FILE"
echo "\`\`\`" >> "$REPORT_FILE"
ip -br addr >> "$REPORT_FILE"
echo "\`\`\`" >> "$REPORT_FILE"

echo "### Docker Daemon Configuration" >> "$REPORT_FILE"
if [ -f "/etc/docker/daemon.json" ]; then
    echo "\`\`\`json" >> "$REPORT_FILE"
    cat "/etc/docker/daemon.json" >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
else
    echo "No custom Docker daemon configuration found" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"

# Document power management configuration
echo -e "${YELLOW}Documenting power management configuration...${NC}"
echo "## 6. POWER MANAGEMENT CONFIGURATION" >> "$REPORT_FILE"

echo "### Startup Script" >> "$REPORT_FILE"
if [ -f "/usr/local/bin/node_startup.sh" ]; then
    echo "Startup script is installed at \`/usr/local/bin/node_startup.sh\`" >> "$REPORT_FILE"
    echo "\`\`\`bash" >> "$REPORT_FILE"
    head -n 30 "/usr/local/bin/node_startup.sh" >> "$REPORT_FILE"
    echo "..." >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
    
    echo "Systemd service status:" >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
    systemctl status node-startup.service 2>/dev/null || echo "Service not installed" >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
else
    echo "No startup script found at /usr/local/bin/node_startup.sh" >> "$REPORT_FILE"
fi

echo "### Shutdown Script" >> "$REPORT_FILE"
if [ -f "/usr/local/bin/node_shutdown.sh" ]; then
    echo "Shutdown script is installed at \`/usr/local/bin/node_shutdown.sh\`" >> "$REPORT_FILE"
    echo "\`\`\`bash" >> "$REPORT_FILE"
    head -n 30 "/usr/local/bin/node_shutdown.sh" >> "$REPORT_FILE"
    echo "..." >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
    
    echo "Systemd service status:" >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
    systemctl status node-shutdown.service 2>/dev/null || echo "Service not installed" >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
else
    echo "No shutdown script found at /usr/local/bin/node_shutdown.sh" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"

# Document mobile node configuration
echo -e "${YELLOW}Documenting mobile node configuration...${NC}"
echo "## 7. MOBILE NODE CONFIGURATION" >> "$REPORT_FILE"

echo "### Samsung A50 Configuration" >> "$REPORT_FILE"
if [ -d "/home/optiplex_780_1/Desktop/mobile_node_project" ]; then
    echo "Mobile node project directory found at \`/home/optiplex_780_1/Desktop/mobile_node_project\`" >> "$REPORT_FILE"
    
    echo "#### Scripts" >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
    ls -la /home/optiplex_780_1/Desktop/mobile_node_project/scripts/ 2>/dev/null || echo "No scripts directory found" >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
    
    echo "#### Quick Start Script" >> "$REPORT_FILE"
    if [ -f "/home/optiplex_780_1/Desktop/mobile_node_project/quick_start.sh" ]; then
        echo "\`\`\`bash" >> "$REPORT_FILE"
        cat "/home/optiplex_780_1/Desktop/mobile_node_project/quick_start.sh" >> "$REPORT_FILE"
        echo "\`\`\`" >> "$REPORT_FILE"
    else
        echo "No quick start script found" >> "$REPORT_FILE"
    fi
else
    echo "No mobile node project directory found" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"

# Document laptop node configuration
echo -e "${YELLOW}Documenting laptop node configurations...${NC}"
echo "## 8. LAPTOP NODE CONFIGURATIONS" >> "$REPORT_FILE"

echo "### Lenovo Laptop Configuration" >> "$REPORT_FILE"
if [ -d "/home/optiplex_780_1/Desktop/lenovo_node_config" ]; then
    echo "Lenovo node config directory found at \`/home/optiplex_780_1/Desktop/lenovo_node_config\`" >> "$REPORT_FILE"
    
    echo "#### Scripts" >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
    ls -la /home/optiplex_780_1/Desktop/lenovo_node_config/ >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
else
    echo "No dedicated Lenovo configuration directory found" >> "$REPORT_FILE"
fi

echo "### HP Laptop Configuration" >> "$REPORT_FILE"
if [ -f "/home/optiplex_780_1/Desktop/BlueprintProject/scripts/hp_laptop_setup.ps1" ]; then
    echo "HP laptop setup script found at \`/home/optiplex_780_1/Desktop/BlueprintProject/scripts/hp_laptop_setup.ps1\`" >> "$REPORT_FILE"
else
    echo "No HP laptop setup script found" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"

# Monitoring and visualization
echo -e "${YELLOW}Documenting monitoring and visualization...${NC}"
echo "## 9. MONITORING AND VISUALIZATION" >> "$REPORT_FILE"

echo "### Swarm Visualizer" >> "$REPORT_FILE"
if [ "$SWARM_STATUS" = "active" ] && [ "$NODE_ROLE" = "true" ]; then
    VIZ_SERVICE=$(docker service ls --filter name=visualizer -q)
    if [ -n "$VIZ_SERVICE" ]; then
        echo "Swarm visualizer is running:" >> "$REPORT_FILE"
        echo "\`\`\`" >> "$REPORT_FILE"
        docker service ps visualizer >> "$REPORT_FILE"
        echo "\`\`\`" >> "$REPORT_FILE"
        
        echo "Access at: http://192.168.0.200:8080" >> "$REPORT_FILE"
    else
        echo "No swarm visualizer service running" >> "$REPORT_FILE"
    fi
else
    echo "Cannot check for visualizer - not a swarm manager" >> "$REPORT_FILE"
fi

echo "### Prometheus Monitoring" >> "$REPORT_FILE"
if [ -d "/home/optiplex_780_1/Desktop/monitoring" ]; then
    echo "Monitoring directory found at \`/home/optiplex_780_1/Desktop/monitoring\`" >> "$REPORT_FILE"
    
    if [ -f "/home/optiplex_780_1/Desktop/monitoring/docker-compose.yml" ]; then
        echo "Docker Compose configuration:" >> "$REPORT_FILE"
        echo "\`\`\`yaml" >> "$REPORT_FILE"
        cat "/home/optiplex_780_1/Desktop/monitoring/docker-compose.yml" >> "$REPORT_FILE"
        echo "\`\`\`" >> "$REPORT_FILE"
    fi
    
    if [ -f "/home/optiplex_780_1/Desktop/monitoring/prometheus.yml" ]; then
        echo "Prometheus configuration:" >> "$REPORT_FILE"
        echo "\`\`\`yaml" >> "$REPORT_FILE"
        cat "/home/optiplex_780_1/Desktop/monitoring/prometheus.yml" >> "$REPORT_FILE"
        echo "\`\`\`" >> "$REPORT_FILE"
    fi
else
    echo "No monitoring directory found" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"

# Document deployment strategies
echo -e "${YELLOW}Documenting deployment and upgrade strategies...${NC}"
echo "## 10. DEPLOYMENT AND UPGRADE STRATEGIES" >> "$REPORT_FILE"

echo "### Load Balancing Configuration" >> "$REPORT_FILE"
if [ -f "/home/optiplex_780_1/Desktop/Cluster/QuickAccess/laptop_load_balance.sh" ]; then
    echo "Load balancing script found at \`/home/optiplex_780_1/Desktop/Cluster/QuickAccess/laptop_load_balance.sh\`" >> "$REPORT_FILE"
    echo "\`\`\`bash" >> "$REPORT_FILE"
    cat "/home/optiplex_780_1/Desktop/Cluster/QuickAccess/laptop_load_balance.sh" >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
else
    echo "No load balancing script found" >> "$REPORT_FILE"
fi

echo "### Service Update Strategy" >> "$REPORT_FILE"
echo "Default Docker Swarm update configuration:" >> "$REPORT_FILE"
echo "- Rolling updates with one task at a time" >> "$REPORT_FILE"
echo "- Wait until first task is \"running\" before starting next" >> "$REPORT_FILE"
echo "- Automatic rollback on failed deployments" >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"

# Document known issues and recommendations
echo -e "${YELLOW}Adding known issues and recommendations...${NC}"
echo "## 11. KNOWN ISSUES AND RECOMMENDATIONS" >> "$REPORT_FILE"

echo "### Known Issues" >> "$REPORT_FILE"
echo "1. **Inconsistent Node Naming**: Inconsistent node hostnames in swarm (e.g. 'docker-desktop' for Lenovo laptop)" >> "$REPORT_FILE"
echo "2. **Missing SSH Key Authentication**: Password authentication is used instead of key-based" >> "$REPORT_FILE"
echo "3. **Service Recovery**: No automatic service recovery mechanisms for container crashes" >> "$REPORT_FILE"
echo "4. **Backup Strategy**: Limited automated backup solutions for service data" >> "$REPORT_FILE"
echo "5. **Mobile Integration**: Mobile node integration is incomplete and requires direct SSH access" >> "$REPORT_FILE"

echo "### Recommendations" >> "$REPORT_FILE"
echo "1. **Standardize Naming Convention**: Apply consistent naming for all nodes" >> "$REPORT_FILE"
echo "2. **Implement SSH Key Authentication**: Replace password authentication with key-based auth" >> "$REPORT_FILE"
echo "3. **Deploy Health Checks**: Add proper health checks to all services" >> "$REPORT_FILE"
echo "4. **Implement Volume Backups**: Regular backups of service data volumes" >> "$REPORT_FILE"
echo "5. **Mobile Integration**: Complete mobile node integration with proper security" >> "$REPORT_FILE"
echo "6. **Load Testing**: Perform load testing to identify bottlenecks" >> "$REPORT_FILE"
echo "7. **Security Audit**: Conduct a security audit and implement recommendations" >> "$REPORT_FILE"

echo "" >> "$REPORT_FILE"

# Final section
echo "## 12. MIGRATION PLAN" >> "$REPORT_FILE"
echo "### Steps for Migration to New System" >> "$REPORT_FILE"
echo "1. **Document Current Deployment**: Complete inventory of services, volumes, and configurations" >> "$REPORT_FILE"
echo "2. **Back Up Data**: Create backups of all persistent data volumes" >> "$REPORT_FILE"
echo "3. **Set Up New Swarm**: Initialize new swarm on target infrastructure" >> "$REPORT_FILE"
echo "4. **Transfer Configurations**: Copy and adapt all configuration files" >> "$REPORT_FILE"
echo "5. **Deploy Services**: Recreate services on new swarm with same configurations" >> "$REPORT_FILE"
echo "6. **Restore Data**: Restore backed-up data to new volumes" >> "$REPORT_FILE"
echo "7. **Validate Deployment**: Verify all services are running correctly" >> "$REPORT_FILE"
echo "8. **Update DNS/Routing**: Point traffic to new infrastructure" >> "$REPORT_FILE"
echo "9. **Monitor for Issues**: Closely monitor new deployment for 24-48 hours" >> "$REPORT_FILE"
echo "10. **Decommission Old Swarm**: Once stable, shut down old infrastructure" >> "$REPORT_FILE"

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}     CLUSTER INFORMATION COLLECTION COMPLETE         ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo
echo -e "Report saved to: ${YELLOW}$REPORT_FILE${NC}"
echo
echo -e "Use this report for documentation and migration planning."
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
