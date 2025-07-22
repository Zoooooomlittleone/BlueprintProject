#!/bin/bash
# Advanced Load Balancing Script for Docker Swarm
# This script configures Docker Swarm for advanced load balancing and offloading work from the master node

# Set colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print header
echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}    DOCKER SWARM ADVANCED LOAD BALANCING    ${NC}"
echo -e "${BLUE}=====================================================${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}This script must be run as root (use sudo)${NC}"
  exit 1
fi

# Verify we're on the master node
HOSTNAME=$(hostname)
if [ "$HOSTNAME" != "optiplex_780_1" ] && [ "$HOSTNAME" != "master" ]; then
  echo -e "${RED}This script must be run on the master node (optiplex_780_1)${NC}"
  exit 1
fi

# Check if we're in an active swarm
SWARM_STATUS=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)
if [ "$SWARM_STATUS" != "active" ]; then
  echo -e "${RED}Not in an active swarm. Please initialize swarm first.${NC}"
  exit 1
fi

# Check if this node is a manager
NODE_ROLE=$(docker info --format '{{.Swarm.ControlAvailable}}')
if [ "$NODE_ROLE" != "true" ]; then
  echo -e "${RED}This node is not a swarm manager. Cannot continue.${NC}"
  exit 1
fi

# Function to apply node labels
apply_node_labels() {
  echo -e "${YELLOW}Applying node labels for load balancing...${NC}"
  
  # Label the master node
  echo -e "${YELLOW}Labeling master node...${NC}"
  docker node update --label-add node.role=manager --label-add node.type=master optiplex_780_1
  
  # Label Optiplex worker nodes
  echo -e "${YELLOW}Labeling Optiplex worker nodes...${NC}"
  docker node update --label-add node.role=worker --label-add node.type=server --label-add node.capabilities=compute optiplex_780_2
  docker node update --label-add node.role=worker --label-add node.type=server --label-add node.capabilities=compute optiplex70101
  docker node update --label-add node.role=worker --label-add node.type=server --label-add node.capabilities=compute optiplex70102
  
  # Note: If nodes are identified by IP instead of hostname, use these commands:
  # OPTIPLEX_780_2_ID=$(docker node ls --format "{{.ID}}\t{{.Hostname}}" | grep "192.168.0.201" | cut -f1)
  # OPTIPLEX_70101_ID=$(docker node ls --format "{{.ID}}\t{{.Hostname}}" | grep "192.168.0.202" | cut -f1)
  # OPTIPLEX_70102_ID=$(docker node ls --format "{{.ID}}\t{{.Hostname}}" | grep "192.168.0.203" | cut -f1)
  # docker node update --label-add node.role=worker --label-add node.type=server --label-add node.capabilities=compute $OPTIPLEX_780_2_ID
  # docker node update --label-add node.role=worker --label-add node.type=server --label-add node.capabilities=compute $OPTIPLEX_70101_ID
  # docker node update --label-add node.role=worker --label-add node.type=server --label-add node.capabilities=compute $OPTIPLEX_70102_ID
  
  # Label laptop nodes
  echo -e "${YELLOW}Labeling laptop nodes...${NC}"
  docker node update --label-add node.role=worker --label-add node.type=laptop --label-add node.capabilities=display laptopnode
  docker node update --label-add node.role=worker --label-add node.type=laptop --label-add node.capabilities=display docker-desktop
  
  echo -e "${GREEN}✓ Node labels applied${NC}"
}

# Function to set resource limits for nodes
set_resource_limits() {
  echo -e "${YELLOW}Setting resource limits for nodes...${NC}"
  
  # Set resource limits for master node (low limits to preserve resources for management)
  echo -e "${YELLOW}Setting resource limits for master node...${NC}"
  docker node update --availability active --label-add resource.memory=4GB --label-add resource.cpu=2 optiplex_780_1
  
  # Set resource limits for Optiplex worker nodes (higher limits for computation)
  echo -e "${YELLOW}Setting resource limits for Optiplex worker nodes...${NC}"
  docker node update --availability active --label-add resource.memory=12GB --label-add resource.cpu=6 optiplex_780_2
  docker node update --availability active --label-add resource.memory=12GB --label-add resource.cpu=6 optiplex70101
  docker node update --availability active --label-add resource.memory=12GB --label-add resource.cpu=6 optiplex70102
  
  # Set resource limits for laptop nodes (moderate limits to prevent overheating)
  echo -e "${YELLOW}Setting resource limits for laptop nodes...${NC}"
  docker node update --availability active --label-add resource.memory=4GB --label-add resource.cpu=2 laptopnode
  docker node update --availability active --label-add resource.memory=4GB --label-add resource.cpu=2 docker-desktop
  
  echo -e "${GREEN}✓ Resource limits set${NC}"
}

# Function to create specialized overlay networks
create_specialized_networks() {
  echo -e "${YELLOW}Creating specialized overlay networks...${NC}"
  
  # Create a management network
  if ! docker network ls | grep -q "management-net"; then
    echo -e "${YELLOW}Creating management network...${NC}"
    docker network create --driver overlay --attachable management-net
  fi
  
  # Create a compute network
  if ! docker network ls | grep -q "compute-net"; then
    echo -e "${YELLOW}Creating compute network...${NC}"
    docker network create --driver overlay --attachable compute-net
  fi
  
  # Create a display network
  if ! docker network ls | grep -q "display-net"; then
    echo -e "${YELLOW}Creating display network...${NC}"
    docker network create --driver overlay --attachable display-net
  fi
  
  # Create a data network
  if ! docker network ls | grep -q "data-net"; then
    echo -e "${YELLOW}Creating data network...${NC}"
    docker network create --driver overlay --attachable data-net
  fi
  
  echo -e "${GREEN}✓ Specialized networks created${NC}"
}

# Function to deploy Traefik load balancer
deploy_traefik() {
  echo -e "${YELLOW}Deploying Traefik load balancer...${NC}"
  
  # Create network if it doesn't exist
  if ! docker network ls | grep -q "loadbalance-net"; then
    echo -e "${YELLOW}Creating load balancing network...${NC}"
    docker network create --driver overlay loadbalance-net
  fi
  
  # Create Traefik configuration directory
  mkdir -p /opt/traefik
  
  # Create Traefik configuration file
  echo -e "${YELLOW}Creating Traefik configuration...${NC}"
  cat > /opt/traefik/traefik.toml << TOML
[global]
  checkNewVersion = false
  sendAnonymousUsage = false

[entryPoints]
  [entryPoints.web]
    address = ":80"
  [entryPoints.websecure]
    address = ":443"
  [entryPoints.metrics]
    address = ":8082"

[api]
  dashboard = true
  insecure = true

[providers]
  [providers.docker]
    endpoint = "unix:///var/run/docker.sock"
    swarmMode = true
    watch = true
    exposedByDefault = false
    network = "loadbalance-net"
  
  [providers.file]
    directory = "/etc/traefik/dynamic"
    watch = true

[metrics]
  [metrics.prometheus]
    entryPoint = "metrics"
    addServicesLabels = true
    addEntryPointsLabels = true
    
[accessLog]
  filePath = "/var/log/traefik/access.log"
  bufferingSize = 100

[log]
  level = "INFO"
  filePath = "/var/log/traefik/traefik.log"
TOML

  # Create dynamic configuration directory
  mkdir -p /opt/traefik/dynamic
  
  # Create dynamic configuration for advanced routing
  cat > /opt/traefik/dynamic/advanced-routing.toml << ROUTING
[http.middlewares]
  [http.middlewares.compress.compress]
  [http.middlewares.retry.retry]
    attempts = 3
    initialInterval = "500ms"
  [http.middlewares.ratelimit.rateLimit]
    average = 100
    burst = 50

[http.serversTransports]
  [http.serversTransports.default]
    insecureSkipVerify = true
ROUTING

  # Create Docker Compose file for Traefik
  echo -e "${YELLOW}Creating Traefik deployment file...${NC}"
  cat > /opt/traefik/docker-compose.yml << YAML
version: '3.8'

services:
  traefik:
    image: traefik:v2.9
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.swarmMode=true"
      - "--providers.docker.exposedByDefault=false"
      - "--providers.file.directory=/etc/traefik/dynamic"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--entrypoints.metrics.address=:8082"
      - "--metrics.prometheus=true"
      - "--metrics.prometheus.entryPoint=metrics"
      - "--accesslog=true"
      - "--accesslog.filepath=/var/log/access.log"
      - "--log.level=INFO"
      - "--log.filepath=/var/log/traefik.log"
    ports:
      - "80:80"
      - "443:443"
      - "8000:8080"
      - "8082:8082"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /opt/traefik/traefik.toml:/etc/traefik/traefik.toml
      - /opt/traefik/dynamic:/etc/traefik/dynamic
    networks:
      - loadbalance-net
      - management-net
    deploy:
      mode: replicated
      replicas: 1
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.dashboard.rule=Host(`traefik.local`)"
        - "traefik.http.routers.dashboard.service=api@internal"
        - "traefik.http.services.dashboard.loadbalancer.server.port=8080"
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
        window: 120s
      resources:
        limits:
          cpus: '0.50'
          memory: 256M
        reservations:
          cpus: '0.25'
          memory: 128M

networks:
  loadbalance-net:
    external: true
  management-net:
    external: true
YAML

  # Deploy Traefik
  echo -e "${YELLOW}Deploying Traefik stack...${NC}"
  docker stack deploy -c /opt/traefik/docker-compose.yml loadbalancer
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Traefik deployed successfully${NC}"
  else
    echo -e "${RED}✗ Failed to deploy Traefik${NC}"
    return 1
  fi
  
  # Add hosts entry for traefik.local
  if ! grep -q "traefik.local" /etc/hosts; then
    echo -e "${YELLOW}Adding traefik.local to /etc/hosts${NC}"
    echo "127.0.0.1 traefik.local" >> /etc/hosts
  fi
  
  return 0
}

# Function to create node drain/restore utilities
create_node_utils() {
  echo -e "${YELLOW}Creating node management utilities...${NC}"
  
  # Create a script to drain a node
  cat > /home/optiplex_780_1/Desktop/BlueprintProject/scripts/drain_node.sh << 'EOF'
#!/bin/bash
# Script to safely drain a node for maintenance

# Set colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ $# -ne 1 ]; then
  echo -e "${RED}Usage: $0 <node_name>${NC}"
  exit 1
fi

NODE_NAME=$1

echo -e "${YELLOW}Draining node $NODE_NAME for maintenance...${NC}"

# Check if the node exists
if ! docker node ls --filter name=$NODE_NAME | grep -q $NODE_NAME; then
  echo -e "${RED}Error: Node $NODE_NAME not found${NC}"
  exit 1
fi

# Drain the node
docker node update --availability drain $NODE_NAME

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✓ Node $NODE_NAME drained successfully${NC}"
  echo -e "${YELLOW}The node will no longer receive new tasks.${NC}"
  echo -e "${YELLOW}Existing tasks on this node will be rescheduled to other nodes.${NC}"
  echo -e "${YELLOW}To restore the node after maintenance, run:${NC}"
  echo -e "${YELLOW}  ./restore_node.sh $NODE_NAME${NC}"
else
  echo -e "${RED}✗ Failed to drain node $NODE_NAME${NC}"
fi
EOF

  # Create a script to restore a node
  cat > /home/optiplex_780_1/Desktop/BlueprintProject/scripts/restore_node.sh << 'EOF'
#!/bin/bash
# Script to restore a drained node

# Set colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [ $# -ne 1 ]; then
  echo -e "${RED}Usage: $0 <node_name>${NC}"
  exit 1
fi

NODE_NAME=$1

echo -e "${YELLOW}Restoring node $NODE_NAME to active state...${NC}"

# Check if the node exists
if ! docker node ls --filter name=$NODE_NAME | grep -q $NODE_NAME; then
  echo -e "${RED}Error: Node $NODE_NAME not found${NC}"
  exit 1
fi

# Restore the node
docker node update --availability active $NODE_NAME

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✓ Node $NODE_NAME restored successfully${NC}"
  echo -e "${YELLOW}The node will now receive new tasks.${NC}"
else
  echo -e "${RED}✗ Failed to restore node $NODE_NAME${NC}"
fi
EOF

  # Create service constraint template examples
  mkdir -p /home/optiplex_780_1/Desktop/BlueprintProject/templates
  
  # Create a template for compute-intensive services
  cat > /home/optiplex_780_1/Desktop/BlueprintProject/templates/compute-service-template.yml << 'EOF'
version: '3.8'

services:
  compute-service:
    image: your-compute-image:latest
    deploy:
      placement:
        constraints:
          - node.labels.node.type == server
          - node.labels.node.capabilities == compute
      resources:
        limits:
          cpus: '4'
          memory: 8G
        reservations:
          cpus: '2'
          memory: 4G
    networks:
      - compute-net

networks:
  compute-net:
    external: true
EOF

  # Create a template for display/frontend services
  cat > /home/optiplex_780_1/Desktop/BlueprintProject/templates/display-service-template.yml << 'EOF'
version: '3.8'

services:
  frontend-service:
    image: your-frontend-image:latest
    deploy:
      placement:
        constraints:
          - node.labels.node.type == laptop
          - node.labels.node.capabilities == display
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '0.5'
          memory: 512M
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.frontend.rule=Host(`frontend.local`)"
        - "traefik.http.services.frontend.loadbalancer.server.port=80"
    networks:
      - display-net
      - loadbalance-net

networks:
  display-net:
    external: true
  loadbalance-net:
    external: true
EOF

  # Create a template for management services
  cat > /home/optiplex_780_1/Desktop/BlueprintProject/templates/management-service-template.yml << 'EOF'
version: '3.8'

services:
  management-service:
    image: your-management-image:latest
    deploy:
      placement:
        constraints:
          - node.labels.node.role == manager
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.1'
          memory: 128M
    networks:
      - management-net

networks:
  management-net:
    external: true
EOF

  # Make scripts executable
  chmod +x /home/optiplex_780_1/Desktop/BlueprintProject/scripts/drain_node.sh
  chmod +x /home/optiplex_780_1/Desktop/BlueprintProject/scripts/restore_node.sh
  
  echo -e "${GREEN}✓ Node management utilities created${NC}"
}

# Function to create advanced service placement rules
create_placement_rules() {
  echo -e "${YELLOW}Creating advanced service placement rules...${NC}"
  
  # Create a directory for placement rules
  mkdir -p /home/optiplex_780_1/Desktop/BlueprintProject/configs
  
  # Create a configuration file for placement rules
  cat > /home/optiplex_780_1/Desktop/BlueprintProject/configs/swarm_placement_rules.md << 'EOF'
# Docker Swarm Service Placement Rules

This document outlines the rules for placing services on specific nodes in the Docker Swarm cluster.

## Node Types

The cluster has the following node types:

- **Master Node**: For management tasks only
- **Server Nodes**: For compute-intensive tasks
- **Laptop Nodes**: For display/frontend services

## Placement Constraints

Use the following constraints when deploying services:

### For Management Services

```yaml
deploy:
  placement:
    constraints:
      - node.labels.node.role == manager
```

### For Compute-Intensive Services

```yaml
deploy:
  placement:
    constraints:
      - node.labels.node.type == server
      - node.labels.node.capabilities == compute
```

### For Frontend/Display Services

```yaml
deploy:
  placement:
    constraints:
      - node.labels.node.type == laptop
      - node.labels.node.capabilities == display
```

## Resource Limits

Use appropriate resource limits to prevent resource exhaustion:

### For Master Node

```yaml
deploy:
  resources:
    limits:
      cpus: '0.5'
      memory: 512M
    reservations:
      cpus: '0.1'
      memory: 128M
```

### For Server Nodes

```yaml
deploy:
  resources:
    limits:
      cpus: '4'
      memory: 8G
    reservations:
      cpus: '1'
      memory: 2G
```

### For Laptop Nodes

```yaml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 2G
    reservations:
      cpus: '0.5'
      memory: 512M
```

## Network Usage

Connect services to appropriate networks:

- Management services: `management-net`
- Compute services: `compute-net`
- Frontend services: `display-net` and `loadbalance-net`
- Data services: `data-net`
EOF

  echo -e "${GREEN}✓ Advanced placement rules created${NC}"
}

# Create service distribution script
create_service_distribution() {
  echo -e "${YELLOW}Creating service distribution utility...${NC}"
  
  cat > /home/optiplex_780_1/Desktop/BlueprintProject/scripts/distribute_services.sh << 'EOF'
#!/bin/bash
# Service distribution script for Docker Swarm
# This script redistributes services to balance load across nodes

# Set colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}    DOCKER SWARM SERVICE DISTRIBUTION    ${NC}"
echo -e "${BLUE}=====================================================${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}This script must be run as root (use sudo)${NC}"
  exit 1
fi

# Verify we're on the master node
HOSTNAME=$(hostname)
if [ "$HOSTNAME" != "optiplex_780_1" ] && [ "$HOSTNAME" != "master" ]; then
  echo -e "${RED}This script must be run on the master node (optiplex_780_1)${NC}"
  exit 1
fi

# Function to get node load information
get_node_load() {
  echo -e "${YELLOW}Analyzing node load...${NC}"
  
  echo "Node Load Analysis:" > /tmp/node_load.txt
  echo "===================" >> /tmp/node_load.txt
  echo "" >> /tmp/node_load.txt
  
  # Get list of nodes
  docker node ls --format "{{.Hostname}}" | while read -r node; do
    echo "Node: $node" >> /tmp/node_load.txt
    echo "  Services:" >> /tmp/node_load.txt
    
    # Get list of tasks on the node
    docker node ps $node --format "{{.Name}}" | while read -r task; do
      echo "    - $task" >> /tmp/node_load.txt
    done
    
    # Count tasks
    TASK_COUNT=$(docker node ps $node | wc -l)
    TASK_COUNT=$((TASK_COUNT - 1))  # Subtract header row
    
    echo "  Total tasks: $TASK_COUNT" >> /tmp/node_load.txt
    echo "" >> /tmp/node_load.txt
  done
  
  cat /tmp/node_load.txt
  
  echo -e "${GREEN}✓ Node load analysis complete${NC}"
}

# Function to redistribute services
redistribute_services() {
  echo -e "${YELLOW}Redistributing services for optimal load balancing...${NC}"
  
  # Get all services
  SERVICES=$(docker service ls --format "{{.Name}}")
  
  for service in $SERVICES; do
    echo -e "${YELLOW}Analyzing service: $service${NC}"
    
    # Get service information
    SERVICE_INFO=$(docker service inspect $service)
    
    # Check if the service has placement constraints
    if echo "$SERVICE_INFO" | grep -q "Constraints"; then
      echo "  Service already has placement constraints. Skipping."
      continue
    fi
    
    # Determine appropriate node type based on service name
    if [[ "$service" == *"compute"* ]] || [[ "$service" == *"worker"* ]] || [[ "$service" == *"processing"* ]]; then
      echo "  Identified as compute service. Placing on server nodes."
      docker service update --constraint-add "node.labels.node.type==server" $service
    elif [[ "$service" == *"frontend"* ]] || [[ "$service" == *"ui"* ]] || [[ "$service" == *"display"* ]]; then
      echo "  Identified as frontend service. Placing on laptop nodes."
      docker service update --constraint-add "node.labels.node.type==laptop" $service
    elif [[ "$service" == *"manage"* ]] || [[ "$service" == *"admin"* ]] || [[ "$service" == *"control"* ]]; then
      echo "  Identified as management service. Placing on manager node."
      docker service update --constraint-add "node.labels.node.role==manager" $service
    else
      echo "  Could not identify service type. Leaving as is."
    fi
  done
  
  echo -e "${GREEN}✓ Service redistribution complete${NC}"
}

# Main menu
echo -e "${YELLOW}Select an option:${NC}"
echo -e "1) Analyze node load"
echo -e "2) Redistribute services"
echo -e "3) Both: analyze and redistribute"
echo -e "4) Exit"

read -p "Enter your choice (1-4): " choice

case $choice in
  1)
    get_node_load
    ;;
  2)
    redistribute_services
    ;;
  3)
    get_node_load
    redistribute_services
    ;;
  4)
    echo -e "${YELLOW}Exiting${NC}"
    exit 0
    ;;
  *)
    echo -e "${RED}Invalid choice${NC}"
    exit 1
    ;;
esac

echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}    SERVICE DISTRIBUTION COMPLETE    ${NC}"
echo -e "${BLUE}=====================================================${NC}"
EOF

  chmod +x /home/optiplex_780_1/Desktop/BlueprintProject/scripts/distribute_services.sh
  
  echo -e "${GREEN}✓ Service distribution utility created${NC}"
}

# Main function to run all components
main() {
  # Apply node labels
  apply_node_labels
  
  # Set resource limits
  set_resource_limits
  
  # Create specialized networks
  create_specialized_networks
  
  # Create node management utilities
  create_node_utils
  
  # Create placement rules
  create_placement_rules
  
  # Create service distribution utility
  create_service_distribution
  
  # Ask if user wants to deploy Traefik
  echo -e "${YELLOW}Do you want to deploy Traefik load balancer now? (y/n)${NC}"
  read -r deploy_lb
  
  if [[ "$deploy_lb" =~ ^[Yy]$ ]]; then
    deploy_traefik
  else
    echo -e "${YELLOW}Traefik deployment skipped. You can deploy it later by running:${NC}"
    echo -e "  ${YELLOW}sudo /opt/traefik/setup_load_balancer.sh${NC}"
  fi
  
  # Create desktop shortcut
  echo -e "${YELLOW}Creating desktop shortcut...${NC}"
  cat > "/home/optiplex_780_1/Desktop/Advanced_Load_Balancing.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Advanced Load Balancing
Comment=Configure Docker Swarm advanced load balancing
Exec=bash -c 'cd /home/optiplex_780_1/Desktop/BlueprintProject/scripts && sudo ./advanced_load_balancing.sh; read -p "Press Enter to close..."'
Icon=network-transmit-receive
Terminal=true
StartupNotify=true
EOF

  chmod +x "/home/optiplex_780_1/Desktop/Advanced_Load_Balancing.desktop"
  
  echo -e "${BLUE}=====================================================${NC}"
  echo -e "${GREEN}    ADVANCED LOAD BALANCING SETUP COMPLETE    ${NC}"
  echo -e "${BLUE}=====================================================${NC}"
  echo
  echo -e "${GREEN}The following components have been set up:${NC}"
  echo -e "  - ${YELLOW}Node labels${NC}: Applied to all nodes"
  echo -e "  - ${YELLOW}Resource limits${NC}: Set for all nodes"
  echo -e "  - ${YELLOW}Specialized networks${NC}: Created for different service types"
  echo -e "  - ${YELLOW}Node management utilities${NC}: For draining and restoring nodes"
  echo -e "  - ${YELLOW}Placement rules${NC}: For optimal service placement"
  echo -e "  - ${YELLOW}Service distribution utility${NC}: For balancing services across nodes"
  if [[ "$deploy_lb" =~ ^[Yy]$ ]]; then
    echo -e "  - ${YELLOW}Traefik load balancer${NC}: Deployed and configured"
  fi
  echo
  echo -e "${YELLOW}Master node is now configured to primarily handle management tasks.${NC}"
  echo -e "${YELLOW}Compute-intensive tasks will be directed to server nodes.${NC}"
  echo -e "${YELLOW}Frontend/display services will be directed to laptop nodes.${NC}"
  echo
  echo -e "${YELLOW}To distribute existing services, run:${NC}"
  echo -e "  ${YELLOW}sudo /home/optiplex_780_1/Desktop/BlueprintProject/scripts/distribute_services.sh${NC}"
  echo
  echo -e "${BLUE}=====================================================${NC}"
}

# Run the main function
main
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
