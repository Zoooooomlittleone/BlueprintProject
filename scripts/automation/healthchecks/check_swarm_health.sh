#!/bin/bash
# Health check script for Docker Swarm
# This script checks the health of all nodes and services in the swarm

# Set up logging
LOG_DIR="/home/optiplex_780_1/Desktop/BlueprintProject/logs"
LOG_FILE="$LOG_DIR/swarm_health_$(date +%Y%m%d).log"
ALERT_LOG="$LOG_DIR/swarm_alerts.log"

# Ensure log directory exists
mkdir -p $LOG_DIR

# Log with timestamp
log_message() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Log alerts
log_alert() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALERT: $1" >> "$ALERT_LOG"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALERT: $1" >> "$LOG_FILE"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALERT: $1"
}

# Start health check
log_message "Starting Docker Swarm health check"

# Check if Docker daemon is running
if ! systemctl is-active --quiet docker; then
  log_alert "Docker daemon is not running on master node!"
  systemctl start docker
  log_message "Attempted to start Docker daemon"
fi

# Check if we're in a swarm
SWARM_STATUS=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)
if [ "$SWARM_STATUS" != "active" ]; then
  log_alert "Node is not in an active swarm!"
  exit 1
fi

# Check if this node is a manager
NODE_ROLE=$(docker info --format '{{.Swarm.ControlAvailable}}')
if [ "$NODE_ROLE" != "true" ]; then
  log_alert "This node is not a swarm manager!"
  exit 1
fi

# Check swarm nodes
log_message "Checking swarm nodes..."
NODES_DOWN=0
TOTAL_NODES=0

while read -r line; do
  if [[ $line == *"*"*"Leader"* ]]; then
    # This is the leader node line from docker node ls
    continue
  fi
  
  if [[ $line == *"Ready"*"Active"* ]]; then
    # Node is healthy
    NODE_ID=$(echo "$line" | awk '{print $1}')
    NODE_NAME=$(echo "$line" | awk '{print $2}')
    log_message "Node $NODE_NAME ($NODE_ID) is healthy"
  else
    # Node has issues
    NODE_ID=$(echo "$line" | awk '{print $1}')
    NODE_NAME=$(echo "$line" | awk '{print $2}')
    NODE_STATUS=$(echo "$line" | awk '{print $3}')
    NODE_AVAILABILITY=$(echo "$line" | awk '{print $4}')
    
    log_alert "Node $NODE_NAME ($NODE_ID) has issues: Status=$NODE_STATUS, Availability=$NODE_AVAILABILITY"
    NODES_DOWN=$((NODES_DOWN + 1))
  fi
  
  TOTAL_NODES=$((TOTAL_NODES + 1))
done < <(docker node ls | tail -n +2)

if [ $NODES_DOWN -gt 0 ]; then
  log_alert "$NODES_DOWN out of $TOTAL_NODES nodes are experiencing issues"
else
  log_message "All $TOTAL_NODES nodes are healthy"
fi

# Check services health
log_message "Checking service health..."
SERVICES_UNHEALTHY=0
TOTAL_SERVICES=0

while read -r line; do
  # Extract service information
  SERVICE_ID=$(echo "$line" | awk '{print $1}')
  SERVICE_NAME=$(echo "$line" | awk '{print $2}')
  SERVICE_REPLICAS=$(echo "$line" | awk '{print $4}')
  
  # Check if all replicas are running
  if [[ "$SERVICE_REPLICAS" == *"/"* ]]; then
    RUNNING=$(echo "$SERVICE_REPLICAS" | cut -d '/' -f 1)
    EXPECTED=$(echo "$SERVICE_REPLICAS" | cut -d '/' -f 2)
    
    if [ "$RUNNING" -lt "$EXPECTED" ]; then
      log_alert "Service $SERVICE_NAME ($SERVICE_ID) has $RUNNING/$EXPECTED replicas running"
      SERVICES_UNHEALTHY=$((SERVICES_UNHEALTHY + 1))
    else
      log_message "Service $SERVICE_NAME has all replicas running ($SERVICE_REPLICAS)"
    fi
  fi
  
  TOTAL_SERVICES=$((TOTAL_SERVICES + 1))
done < <(docker service ls | tail -n +2)

if [ $SERVICES_UNHEALTHY -gt 0 ]; then
  log_alert "$SERVICES_UNHEALTHY out of $TOTAL_SERVICES services are unhealthy"
else
  log_message "All $TOTAL_SERVICES services are healthy"
fi

# Check container health
log_message "Checking container health..."
CONTAINERS_UNHEALTHY=0
TOTAL_CONTAINERS=0

while read -r line; do
  CONTAINER_ID=$(echo "$line" | awk '{print $1}')
  CONTAINER_NAME=$(echo "$line" | awk '{print $NF}')
  CONTAINER_STATUS=$(echo "$line" | awk '{print $3}')
  
  if [[ "$CONTAINER_STATUS" == *"(unhealthy)"* ]]; then
    log_alert "Container $CONTAINER_NAME ($CONTAINER_ID) is unhealthy"
    CONTAINERS_UNHEALTHY=$((CONTAINERS_UNHEALTHY + 1))
  elif [[ "$CONTAINER_STATUS" != *"Up"* ]]; then
    log_alert "Container $CONTAINER_NAME ($CONTAINER_ID) is not running: $CONTAINER_STATUS"
    CONTAINERS_UNHEALTHY=$((CONTAINERS_UNHEALTHY + 1))
  fi
  
  TOTAL_CONTAINERS=$((TOTAL_CONTAINERS + 1))
done < <(docker ps -a | tail -n +2)

if [ $CONTAINERS_UNHEALTHY -gt 0 ]; then
  log_alert "$CONTAINERS_UNHEALTHY out of $TOTAL_CONTAINERS containers are unhealthy"
else
  log_message "All $TOTAL_CONTAINERS containers are healthy"
fi

# Check resource usage on each node
log_message "Checking resource usage on nodes..."

for node in $(docker node ls --format "{{.Hostname}}"); do
  if [ "$node" == "$(hostname)" ]; then
    # Check CPU usage locally
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    MEM_USAGE=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
    DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
      log_alert "High CPU usage on $node: $CPU_USAGE%"
    fi
    
    if (( $(echo "$MEM_USAGE > 80" | bc -l) )); then
      log_alert "High memory usage on $node: $MEM_USAGE%"
    fi
    
    if (( $(echo "$DISK_USAGE > 80" | bc -l) )); then
      log_alert "High disk usage on $node: $DISK_USAGE%"
    fi
    
    log_message "Resource usage on $node - CPU: $CPU_USAGE%, Memory: $MEM_USAGE%, Disk: $DISK_USAGE%"
  else
    # Skip remote checks for now
    log_message "Skipping remote resource check for $node (to be implemented)"
  fi
done

# Final report
log_message "Health check completed"
if [ $NODES_DOWN -gt 0 ] || [ $SERVICES_UNHEALTHY -gt 0 ] || [ $CONTAINERS_UNHEALTHY -gt 0 ]; then
  log_alert "Issues detected in the swarm cluster! Check logs for details."
  exit 1
else
  log_message "Swarm cluster is healthy"
  exit 0
fi
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
