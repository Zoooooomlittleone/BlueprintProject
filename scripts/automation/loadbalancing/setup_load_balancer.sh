#!/bin/bash

# Load Balancer Setup Script for Docker Swarm
# This script deploys Traefik as a load balancer for the swarm

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================================\033[0m"
echo -e "${BLUE}     DOCKER SWARM LOAD BALANCER SETUP               \033[0m"
echo -e "${BLUE}====================================================\033[0m"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}This script must be run as root (use sudo)\033[0m"
  exit 1
fi

# Check if we're in swarm mode
SWARM_STATUS=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)
if [ "$SWARM_STATUS" != "active" ]; then
    echo -e "${RED}Not in an active swarm. Please initialize swarm first.\033[0m"
    exit 1
fi

# Check if we're a manager
NODE_ROLE=$(docker info --format '{{.Swarm.ControlAvailable}}')
if [ "$NODE_ROLE" != "true" ]; then
    echo -e "${RED}This node is not a swarm manager. Cannot deploy services.\033[0m"
    exit 1
fi

# Create network if it doesn't exist
if ! docker network ls | grep -q "loadbalance-net"; then
    echo -e "${YELLOW}Creating overlay network: loadbalance-net\033[0m"
    docker network create --driver overlay loadbalance-net
fi

# Create Traefik configuration
echo -e "${YELLOW}Creating Traefik configuration...\033[0m"
mkdir -p /opt/traefik
cat > /opt/traefik/traefik.toml << TOML
[entryPoints]
  [entryPoints.web]
    address = ":80"
  [entryPoints.websecure]
    address = ":443"

[api]
  dashboard = true
  insecure = true

[providers]
  [providers.docker]
    endpoint = "unix:///var/run/docker.sock"
    swarmMode = true
    watch = true
    exposedByDefault = false

[accessLog]
TOML

# Create Docker Compose file for Traefik
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
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
    ports:
      - "80:80"
      - "443:443"
      - "8000:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /opt/traefik/traefik.toml:/etc/traefik/traefik.toml
    networks:
      - loadbalance-net
    deploy:
      placement:
        constraints:
          - node.role == manager
      restart_policy:
        condition: on-failure
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.dashboard.rule=Host(`traefik.local`)"
        - "traefik.http.routers.dashboard.service=api@internal"
        - "traefik.http.services.dashboard.loadbalancer.server.port=8080"
      healthcheck:
        test: ["CMD", "traefik", "healthcheck", "--ping"]
        interval: 10s
        timeout: 5s
        retries: 3
        start_period: 30s

networks:
  loadbalance-net:
    external: true
YAML

# Deploy Traefik
echo -e "${YELLOW}Deploying Traefik load balancer...\033[0m"
docker stack deploy -c /opt/traefik/docker-compose.yml loadbalancer

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Traefik load balancer deployed successfully\033[0m"
    echo -e "${GREEN}✓ Traefik dashboard available at http://localhost:8000\033[0m"
    echo -e "${GREEN}✓ To use with services, add these labels to your services:\033[0m"
    echo -e "  - traefik.enable=true"
    echo -e "  - traefik.http.routers.<n>.rule=Host(\`<hostname>\`)"
    echo -e "  - traefik.http.services.<n>.loadbalancer.server.port=<port>"
    
    # Create example service labels documentation
    mkdir -p /opt/traefik/examples
    cat > /opt/traefik/examples/service-example.yml << SERVICE
version: '3.8'

services:
  webapp:
    image: nginx:latest
    networks:
      - loadbalance-net
    deploy:
      replicas: 3
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.webapp.rule=Host(\`webapp.local\`)"
        - "traefik.http.services.webapp.loadbalancer.server.port=80"
        - "traefik.http.routers.webapp.entrypoints=web"

networks:
  loadbalance-net:
    external: true
SERVICE
    
    echo -e "\n${YELLOW}Example service configuration saved to /opt/traefik/examples/service-example.yml\033[0m"
    echo -e "\n${YELLOW}To see all running services:\033[0m"
    docker service ls
else
    echo -e "${RED}✗ Failed to deploy Traefik load balancer\033[0m"
fi

# Add hosts entry for traefik.local
if ! grep -q "traefik.local" /etc/hosts; then
    echo -e "${YELLOW}Adding traefik.local to /etc/hosts\033[0m"
    echo "127.0.0.1 traefik.local" >> /etc/hosts
    echo -e "${GREEN}✓ Added traefik.local to /etc/hosts\033[0m"
fi

echo -e "${BLUE}====================================================\033[0m"
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
