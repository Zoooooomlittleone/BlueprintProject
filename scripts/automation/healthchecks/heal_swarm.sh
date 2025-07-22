#!/bin/bash
# Self-healing script for Docker Swarm
# This script attempts to fix common issues in the swarm

# Set up logging
LOG_DIR="/home/optiplex_780_1/Desktop/BlueprintProject/logs"
LOG_FILE="$LOG_DIR/swarm_healing_$(date +%Y%m%d).log"

# Ensure log directory exists
mkdir -p $LOG_DIR

# Log with timestamp
log_message() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Start healing process
log_message "Starting Docker Swarm healing process"

# Check if Docker daemon is running
if ! systemctl is-active --quiet docker; then
  log_message "Docker daemon is not running, attempting to start it"
  systemctl start docker
  sleep 5
  
  if systemctl is-active --quiet docker; then
    log_message "Successfully started Docker daemon"
  else
    log_message "Failed to start Docker daemon"
    exit 1
  fi
fi

# Check swarm status
SWARM_STATUS=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)
if [ "$SWARM_STATUS" != "active" ]; then
  log_message "Swarm is not active, attempting to restore swarm"
  
  # Try to reinitialize the swarm if this is the manager
  if [ -f "/home/optiplex_780_1/Desktop/BlueprintProject/swarm_token.txt" ]; then
    log_message "Reinitializing swarm from saved token"
    docker swarm init --advertise-addr 192.168.0.200
    log_message "Swarm reinitialized"
  else
    log_message "Cannot restore swarm, no saved token found"
    exit 1
  fi
fi

# Check and restart unhealthy containers
log_message "Checking for unhealthy containers"
for container_id in $(docker ps -q); do
  health_status=$(docker inspect --format '{{.State.Health.Status}}' $container_id 2>/dev/null)
  container_name=$(docker inspect --format '{{.Name}}' $container_id | sed 's/\///')
  
  if [ "$health_status" = "unhealthy" ]; then
    log_message "Restarting unhealthy container: $container_name ($container_id)"
    docker restart $container_id
    log_message "Container restarted"
  fi
done

# Check and fix services with reduced replicas
log_message "Checking for services with reduced replicas"
for service_id in $(docker service ls -q); do
  service_name=$(docker service inspect --format '{{.Spec.Name}}' $service_id)
  desired_replicas=$(docker service inspect --format '{{.Spec.Mode.Replicated.Replicas}}' $service_id 2>/dev/null)
  
  # Skip global services
  if [ -z "$desired_replicas" ]; then
    continue
  fi
  
  current_replicas=$(docker service ls --filter "id=$service_id" --format "{{.Replicas}}" | cut -d '/' -f 1)
  expected_replicas=$(docker service ls --filter "id=$service_id" --format "{{.Replicas}}" | cut -d '/' -f 2)
  
  if [ "$current_replicas" -lt "$expected_replicas" ]; then
    log_message "Service $service_name has $current_replicas/$expected_replicas replicas. Forcing update..."
    docker service update --force $service_id
    log_message "Service update triggered"
  fi
done

# Check for disconnected nodes
log_message "Checking for disconnected nodes"
for node_id in $(docker node ls -q); do
  node_status=$(docker node inspect --format '{{.Status.State}}' $node_id)
  node_name=$(docker node inspect --format '{{.Description.Hostname}}' $node_id)
  
  if [ "$node_status" != "ready" ]; then
    log_message "Node $node_name ($node_id) is not ready: $node_status"
    
    # Check if node is down and we should remove it
    if [ "$node_status" = "down" ]; then
      # Check how long it's been down (if we had that info)
      log_message "Attempting to ping node at $(docker node inspect --format '{{.Status.Addr}}' $node_id)"
      
      if ping -c 3 $(docker node inspect --format '{{.Status.Addr}}' $node_id) > /dev/null; then
        log_message "Node is pingable but marked as down in swarm. Might need manual intervention."
      else
        log_message "Node is not responding to ping. If it remains down, consider removing it with: docker node rm $node_id"
      fi
    fi
  fi
done

# Check for network issues
log_message "Checking for network issues"
# Check overlay networks
for network_id in $(docker network ls --filter driver=overlay -q); do
  network_name=$(docker network inspect --format '{{.Name}}' $network_id)
  log_message "Checking network: $network_name"
  
  # Check if the network is used by any service
  services_using_network=$(docker service ls --format "{{.Name}}" --filter network=$network_name)
  if [ -z "$services_using_network" ]; then
    log_message "Network $network_name is not used by any service. Consider removing it."
  fi
done

# Load balancing checks
log_message "Checking load balancing"
# Check if Traefik is running (if it's our load balancer)
traefik_service=$(docker service ls --filter name=traefik -q)
if [ -n "$traefik_service" ]; then
  traefik_replicas=$(docker service ls --filter name=traefik --format "{{.Replicas}}")
  if [[ "$traefik_replicas" != *"1/1"* ]]; then
    log_message "Traefik load balancer is not running correctly: $traefik_replicas"
    docker service update --force $traefik_service
    log_message "Attempted to fix Traefik service"
  else
    log_message "Traefik load balancer is running correctly"
  fi
fi

# Check disk space and clean up if necessary
log_message "Checking disk space"
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 85 ]; then
  log_message "Disk usage is high ($DISK_USAGE%). Cleaning up unused Docker resources."
  
  # Remove unused containers
  log_message "Removing stopped containers"
  docker container prune -f
  
  # Remove unused images
  log_message "Removing dangling images"
  docker image prune -f
  
  # Remove unused volumes
  log_message "Removing unused volumes"
  docker volume prune -f
  
  # Remove unused networks
  log_message "Removing unused networks"
  docker network prune -f
  
  # Check disk usage after cleanup
  NEW_DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
  log_message "Disk cleanup completed. Usage before: $DISK_USAGE%, after: $NEW_DISK_USAGE%"
fi

# Final report
log_message "Healing process completed"
exit 0
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
