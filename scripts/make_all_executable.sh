#!/bin/bash
# Make all scripts executable
# This script finds and makes executable all .sh files in the BlueprintProject directory

# Set colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}        MAKING ALL SCRIPTS EXECUTABLE        ${NC}"
echo -e "${BLUE}=====================================================${NC}"

# Make setup_automation.sh executable
echo -e "${YELLOW}Making setup_automation.sh executable...${NC}"
chmod +x /home/optiplex_780_1/Desktop/BlueprintProject/scripts/setup_automation.sh
if [ $? -eq 0 ]; then
  echo -e "${GREEN}✓ setup_automation.sh is now executable${NC}"
else
  echo -e "${RED}✗ Failed to make setup_automation.sh executable${NC}"
fi

# Make all other scripts executable
echo -e "${YELLOW}Finding and making executable all .sh files...${NC}"
SCRIPTS_FOUND=0
ERRORS=0

while IFS= read -r script; do
  if [ -f "$script" ]; then
    chmod +x "$script"
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}✓ $script is now executable${NC}"
      SCRIPTS_FOUND=$((SCRIPTS_FOUND + 1))
    else
      echo -e "${RED}✗ Failed to make $script executable${NC}"
      ERRORS=$((ERRORS + 1))
    fi
  fi
done < <(find /home/optiplex_780_1/Desktop/BlueprintProject -name "*.sh")

echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}Made $SCRIPTS_FOUND scripts executable with $ERRORS errors${NC}"

# Fix desktop shortcuts if necessary
echo -e "${YELLOW}Making desktop shortcuts executable...${NC}"
SHORTCUTS_FOUND=0

while IFS= read -r shortcut; do
  if [ -f "$shortcut" ]; then
    chmod +x "$shortcut"
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}✓ $shortcut is now executable${NC}"
      SHORTCUTS_FOUND=$((SHORTCUTS_FOUND + 1))
    else
      echo -e "${RED}✗ Failed to make $shortcut executable${NC}"
    fi
  fi
done < <(find /home/optiplex_780_1/Desktop -name "*.desktop")

echo -e "${GREEN}Made $SHORTCUTS_FOUND desktop shortcuts executable${NC}"
echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}All scripts should now be executable!${NC}"
echo
echo -e "${YELLOW}To set up the automation system, run:${NC}"
echo -e "sudo /home/optiplex_780_1/Desktop/BlueprintProject/scripts/setup_automation.sh"
echo -e "${BLUE}=====================================================${NC}"
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
