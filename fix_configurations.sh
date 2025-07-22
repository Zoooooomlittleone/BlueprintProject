#!/bin/bash
# File: /home/optiplex_780_1/Desktop/BlueprintProject/fix_configurations.sh

# Add color support
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting configuration update...${NC}"

# Base directory
BASE_DIR="/home/optiplex_780_1/Desktop/BlueprintProject"

# Function to update file with sed
update_file() {
    local file_path=$1
    local old_text=$2
    local new_text=$3
    
    if [ -f "$file_path" ]; then
        echo -e "${YELLOW}Updating: $file_path${NC}"
        sed -i "s|$old_text|$new_text|g" "$file_path"
    else
        echo "File not found: $file_path"
    fi
}

# Update synchronized_shutdown.sh
update_file "$BASE_DIR/scripts/synchronized_shutdown.sh" "optiplex70101\")\n            NODE_IP=\"192.168.0.201\"" "optiplex70101\")\n            NODE_IP=\"192.168.0.202\""
update_file "$BASE_DIR/scripts/synchronized_shutdown.sh" "optiplex70102\")\n            NODE_IP=\"192.168.0.202\"" "optiplex70102\")\n            NODE_IP=\"192.168.0.203\""

# Add optiplex_780_2 to synchronized_shutdown.sh
update_file "$BASE_DIR/scripts/synchronized_shutdown.sh" "case \"\$node\" in" "case \"\$node\" in\n        \"optiplex_780_2\")\n            NODE_IP=\"192.168.0.201\" # Dell Optiplex 780_2\n            ;;"

# Update cluster_health_monitor.sh
update_file "$BASE_DIR/scripts/cluster_health_monitor.sh" "optiplex70101\")\n                    NODE_IP=\"192.168.0.201\"" "optiplex70101\")\n                    NODE_IP=\"192.168.0.202\""
update_file "$BASE_DIR/scripts/cluster_health_monitor.sh" "optiplex70102\")\n                    NODE_IP=\"192.168.0.202\"" "optiplex70102\")\n                    NODE_IP=\"192.168.0.203\""

# Add optiplex_780_2 to cluster_health_monitor.sh
update_file "$BASE_DIR/scripts/cluster_health_monitor.sh" "case \"\$hostname\" in" "case \"\$hostname\" in\n                \"optiplex_780_2\")\n                    NODE_IP=\"192.168.0.201\"\n                    ;;"

# Update prometheus.yml in monitoring setup
update_file "$BASE_DIR/monitoring/prometheus.yml" "- '192.168.0.201:9100'  # optiplex70101" "- '192.168.0.202:9100'  # optiplex70101"
update_file "$BASE_DIR/monitoring/prometheus.yml" "- '192.168.0.202:9100'  # optiplex70102" "- '192.168.0.203:9100'  # optiplex70102"

# Add optiplex_780_2 to prometheus.yml
update_file "$BASE_DIR/monitoring/prometheus.yml" "- targets:" "- targets:\n        - '192.168.0.201:9100'  # optiplex_780_2"

# Update generate_blueprint.sh if it exists
if [ -f "$BASE_DIR/generate_blueprint.sh" ]; then
    update_file "$BASE_DIR/generate_blueprint.sh" "collect_node_specs \"optiplex70101\" \"192.168.0.201\"" "collect_node_specs \"optiplex70101\" \"192.168.0.202\""
    update_file "$BASE_DIR/generate_blueprint.sh" "collect_node_specs \"optiplex70102\" \"192.168.0.202\"" "collect_node_specs \"optiplex70102\" \"192.168.0.203\""
    
    # Add optiplex_780_2 to generate_blueprint.sh
    update_file "$BASE_DIR/generate_blueprint.sh" "collect_node_specs \"laptopnode\" \"192.168.0.204\"" "collect_node_specs \"laptopnode\" \"192.168.0.204\"\ncollect_node_specs \"optiplex_780_2\" \"192.168.0.201\""
fi

# Update the BLUEPRINT.md file if it exists
if [ -f "$BASE_DIR/BLUEPRINT.md" ]; then
    update_file "$BASE_DIR/BLUEPRINT.md" "- Dell Optiplex 70101 (hostname: optiplex70101)" "- Dell Optiplex 70101 (hostname: optiplex70101) - 192.168.0.202"
    update_file "$BASE_DIR/BLUEPRINT.md" "- Dell Optiplex 70102 (hostname: optiplex70102)" "- Dell Optiplex 70102 (hostname: optiplex70102) - 192.168.0.203"
    
    # Add optiplex_780_2 to BLUEPRINT.md
    update_file "$BASE_DIR/BLUEPRINT.md" "- HP Laptop (hostname: laptopnode) - 192.168.0.204" "- HP Laptop (hostname: laptopnode) - 192.168.0.204\n  - Dell Optiplex 780_2 (hostname: optiplex_780_2) - 192.168.0.201"
fi

# Now let's connect to the optiplex_780_2 node and join it to the swarm
echo -e "${GREEN}Now connecting to optiplex_780_2 to join it to the swarm...${NC}"

# Get the current join token
JOIN_TOKEN=$(docker swarm join-token worker -q)

# Connect to the node and join the swarm
ssh optiplex_780_1@192.168.0.201 "docker swarm leave --force 2>/dev/null; docker swarm join --token $JOIN_TOKEN 192.168.0.200:2377"

# Verify the node was added
echo -e "${GREEN}Verifying cluster nodes...${NC}"
docker node ls

# Update node labels to lock it in
echo -e "${GREEN}Setting up node labels and constraints...${NC}"

# Find the node ID for optiplex_780_2
NODE_ID=$(docker node ls --filter "name=optiplex_780_2" --format "{{.ID}}")

if [ ! -z "$NODE_ID" ]; then
    # Add labels for the node
    docker node update --label-add node.type=compute --label-add node.location=local --label-add node.persistent=true $NODE_ID
    
    echo -e "${GREEN}Node optiplex_780_2 has been labeled for persistence${NC}"
else
    echo "Node optiplex_780_2 not found in the swarm"
fi

echo -e "${GREEN}Configuration update completed!${NC}"
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
