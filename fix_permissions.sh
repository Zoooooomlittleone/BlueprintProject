#!/bin/bash
# Fix permissions for all scripts and desktop shortcuts
# This script ensures all necessary files have proper permissions

# Set colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}        FIXING FILE PERMISSIONS        ${NC}"
echo -e "${BLUE}=====================================================${NC}"

# Fix permissions for our scripts
echo -e "${YELLOW}Fixing permissions for scripts...${NC}"
chmod +x /home/optiplex_780_1/Desktop/BlueprintProject/scripts/setup_automation.sh
chmod +x /home/optiplex_780_1/Desktop/BlueprintProject/scripts/make_all_executable.sh
chmod +x /home/optiplex_780_1/Desktop/BlueprintProject/fix_permissions.sh

# Fix permissions for automation scripts
echo -e "${YELLOW}Fixing permissions for automation scripts...${NC}"
chmod +x /home/optiplex_780_1/Desktop/BlueprintProject/scripts/automation/healthchecks/check_swarm_health.sh
chmod +x /home/optiplex_780_1/Desktop/BlueprintProject/scripts/automation/healthchecks/heal_swarm.sh
chmod +x /home/optiplex_780_1/Desktop/BlueprintProject/scripts/automation/backups/daily_backup.sh
chmod +x /home/optiplex_780_1/Desktop/BlueprintProject/scripts/automation/loadbalancing/setup_load_balancer.sh
chmod +x /home/optiplex_780_1/Desktop/BlueprintProject/scripts/automation/loadbalancing/setup_monitoring.sh

# Fix permissions for desktop shortcuts
echo -e "${YELLOW}Fixing permissions for desktop shortcuts...${NC}"
chmod +x /home/optiplex_780_1/Desktop/Setup_Swarm_Automation.desktop
chmod +x /home/optiplex_780_1/Desktop/Make_All_Executable.desktop

echo -e "${GREEN}All permissions fixed successfully!${NC}"
echo -e "${BLUE}=====================================================${NC}"
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
