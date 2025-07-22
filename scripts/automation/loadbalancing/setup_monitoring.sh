#!/bin/bash
# Monitoring Dashboard Setup Script for Docker Swarm
# This script deploys Prometheus + Grafana for monitoring

# Set colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}        DOCKER SWARM MONITORING SETUP        ${NC}"
echo -e "${BLUE}=====================================================${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}This script must be run as root (use sudo)${NC}"
  exit 1
fi

# Check if we're in swarm mode
SWARM_STATUS=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)
if [ "$SWARM_STATUS" != "active" ]; then
    echo -e "${RED}Not in an active swarm. Please initialize swarm first.${NC}"
    exit 1
fi

# Check if we're a manager
NODE_ROLE=$(docker info --format '{{.Swarm.ControlAvailable}}')
if [ "$NODE_ROLE" != "true" ]; then
    echo -e "${RED}This node is not a swarm manager. Cannot deploy services.${NC}"
    exit 1
fi

# Create monitoring configuration directory
MONITORING_DIR="/opt/swarm-monitoring"
mkdir -p $MONITORING_DIR
echo -e "${YELLOW}Creating monitoring configuration in $MONITORING_DIR...${NC}"

# Create prometheus.yml
cat > $MONITORING_DIR/prometheus.yml << YAML
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'docker'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
YAML

# Create Docker Compose file for monitoring stack
cat > $MONITORING_DIR/docker-compose.yml << YAML
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - prometheus_data:/prometheus
      - ${MONITORING_DIR}/prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    ports:
      - "9090:9090"
    networks:
      - monitoring-net
    deploy:
      placement:
        constraints:
          - node.role == manager

  grafana:
    image: grafana/grafana:latest
    volumes:
      - grafana_data:/var/lib/grafana
    ports:
      - "3000:3000"
    networks:
      - monitoring-net
    deploy:
      placement:
        constraints:
          - node.role == manager

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    ports:
      - "8080:8080"
    networks:
      - monitoring-net
    deploy:
      mode: global

  node-exporter:
    image: prom/node-exporter:latest
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    ports:
      - "9100:9100"
    networks:
      - monitoring-net
    deploy:
      mode: global

networks:
  monitoring-net:
    driver: overlay

volumes:
  prometheus_data:
  grafana_data:
YAML

# Deploy the monitoring stack
echo -e "${YELLOW}Deploying monitoring stack...${NC}"
docker stack deploy -c $MONITORING_DIR/docker-compose.yml monitoring

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Monitoring stack deployed successfully${NC}"
    echo -e "${GREEN}✓ Prometheus available at http://localhost:9090${NC}"
    echo -e "${GREEN}✓ Grafana available at http://localhost:3000${NC}"
    echo -e "${GREEN}✓ Default Grafana login: admin/admin${NC}"
else
    echo -e "${RED}✗ Failed to deploy monitoring stack${NC}"
fi

# Create a basic setup guide
cat > $MONITORING_DIR/setup_grafana.txt << TXT
=== Grafana Initial Setup Guide ===

1. Access Grafana at http://localhost:3000
2. Login with admin/admin (you'll be prompted to change the password)
3. Add Prometheus as a data source:
   - Click "Configuration" (gear icon) > "Data Sources"
   - Click "Add data source"
   - Select "Prometheus"
   - Set URL to "http://prometheus:9090"
   - Click "Save & Test"

4. Import Docker Swarm dashboard:
   - Click "+" > "Import"
   - Enter dashboard ID: 1321 (Docker Swarm & Container Overview)
   - Select the Prometheus data source you just created
   - Click "Import"

5. You should now have a Docker Swarm monitoring dashboard!
TXT

echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}Monitoring setup guide created at $MONITORING_DIR/setup_grafana.txt${NC}"
echo -e "${BLUE}=====================================================${NC}"
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
