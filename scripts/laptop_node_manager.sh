#!/bin/bash
# Laptop Node Manager for Docker Swarm
# This script manages laptop nodes in the swarm, including optimization, malware scanning,
# firmware updates, and configuring them to run with lid closed

# Set colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print header
echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}    DOCKER SWARM LAPTOP NODE MANAGER    ${NC}"
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
fi# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
