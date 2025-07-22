#!/bin/bash
# Simple health check that actually works correctly

LOG_FILE="/home/optiplex_780_1/Desktop/BlueprintProject/logs/health_check_simple.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Health Check Starting" | tee -a "$LOG_FILE"

# Check nodes
NODE_COUNT=$(docker node ls --format "{{.Hostname}}" | wc -l)
READY_NODES=$(docker node ls --format "{{.Status}}" | grep -c "Ready")
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Nodes: $READY_NODES/$NODE_COUNT ready" | tee -a "$LOG_FILE"

# Check services
SERVICE_COUNT=$(docker service ls --format "{{.Name}}" | wc -l)
HEALTHY_SERVICES=$(docker service ls --format "{{.Replicas}}" | grep -E "^[0-9]+/[0-9]+$" | awk -F'/' '$1==$2' | wc -l)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Services: $HEALTHY_SERVICES/$SERVICE_COUNT healthy" | tee -a "$LOG_FILE"

# Check containers (only running ones)
CONTAINER_COUNT=$(docker ps --format "{{.Names}}" | wc -l)
HEALTHY_CONTAINERS=$(docker ps --format "{{.Status}}" | grep -c "Up")
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Containers: $HEALTHY_CONTAINERS/$CONTAINER_COUNT running" | tee -a "$LOG_FILE"

# Summary
if [ "$READY_NODES" -eq "$NODE_COUNT" ] && [ "$HEALTHY_SERVICES" -eq "$SERVICE_COUNT" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Cluster is HEALTHY" | tee -a "$LOG_FILE"
    exit 0
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ Cluster has issues" | tee -a "$LOG_FILE"
    exit 1
fi
