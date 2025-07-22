#!/bin/bash

# Samsung A50 Integration Script for Docker Swarm Cluster
# This script sets up the Samsung A50 at 192.168.0.210 as a mobile worker node in the Docker Swarm cluster

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Log function
log_message() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}This script must be run as root (use sudo)${NC}"
  exit 1
fi

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}     SAMSUNG A50 INTEGRATION FOR DOCKER SWARM       ${NC}"
echo -e "${BLUE}====================================================${NC}"
echo

# Make sure Docker is running
log_message "Ensuring Docker service is running..."
systemctl is-active --quiet docker || systemctl start docker
if ! systemctl is-active --quiet docker; then
    log_message "${RED}✗ Docker service could not be started${NC}"
    exit 1
fi

# Check if we're in swarm mode and we're a manager
log_message "Verifying swarm manager status..."
SWARM_STATUS=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null)
if [ "$SWARM_STATUS" != "active" ]; then
    log_message "${RED}✗ Not in an active swarm. Initializing swarm...${NC}"
    docker swarm init --advertise-addr 192.168.0.200 || { log_message "${RED}✗ Failed to initialize swarm${NC}"; exit 1; }
else
    NODE_ROLE=$(docker info --format '{{.Swarm.ControlAvailable}}')
    if [ "$NODE_ROLE" != "true" ]; then
        log_message "${RED}✗ This node is not a swarm manager${NC}"
        exit 1
    fi
fi

# Get the worker join token
JOIN_TOKEN=$(docker swarm join-token worker -q)
log_message "Worker join token: $JOIN_TOKEN"

# Check if the Samsung A50 is reachable
log_message "Checking if Samsung A50 is reachable..."
if ! ping -c 1 -W 2 192.168.0.210 &> /dev/null; then
    log_message "${YELLOW}⚠ Samsung A50 not reachable at 192.168.0.210${NC}"
    log_message "Please ensure the Samsung A50 is connected to Wi-Fi with IP 192.168.0.210"
    log_message "and Termux is running with SSH server enabled"
    
    # Ask user if they want to proceed with manual setup instructions
    read -p "Do you want to see manual setup instructions? (y/n): " PROCEED
    if [ "$PROCEED" != "y" ]; then
        log_message "Setup aborted."
        exit 1
    fi
    
    log_message "${YELLOW}========== MANUAL SETUP INSTRUCTIONS ==========${NC}"
    log_message "1. Connect the Samsung A50 to Wi-Fi"
    log_message "2. Install Termux from F-Droid or Play Store"
    log_message "3. In Termux, run:"
    log_message "   pkg update && pkg upgrade"
    log_message "   pkg install openssh"
    log_message "4. Set a password for the Termux user:"
    log_message "   passwd"
    log_message "5. Start the SSH server:"
    log_message "   sshd"
    log_message "6. Find the IP address:"
    log_message "   ip addr | grep 'inet '"
    log_message "7. Configure static IP 192.168.0.210 in your Wi-Fi settings"
    log_message "8. Run this script again once the device is reachable"
    log_message "${YELLOW}=============================================${NC}"
    exit 1
fi

# Check if SSH is running on port 8022
log_message "Checking if SSH is running on Samsung A50..."
if ! nc -z -w 5 192.168.0.210 8022; then
    log_message "${RED}✗ SSH service not detected on Samsung A50${NC}"
    log_message "Please ensure the SSH server is running in Termux:"
    log_message "In Termux, run: sshd"
    exit 1
fi

log_message "${GREEN}✓ SSH service is running on Samsung A50${NC}"

# Determine the correct Termux user
log_message "Determining correct Termux user..."
USER_FOUND=false

for USER_PREFIX in "u0_a" "shell" "root"; do
    for i in {10..200}; do
        USER_ID="${USER_PREFIX}${i}"
        
        log_message "Trying user $USER_ID..."
        if ssh -p 8022 -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes "$USER_ID@192.168.0.210" "echo Connected" &>/dev/null; then
            log_message "${GREEN}✓ Connected successfully with user $USER_ID${NC}"
            USER_FOUND=true
            break 2
        fi
    done
done

if [ "$USER_FOUND" = false ]; then
    log_message "${RED}✗ Could not determine correct Termux user${NC}"
    log_message "Please check your Termux setup and ensure the SSH server is correctly configured"
    
    # Ask user to provide the username manually
    read -p "Enter the Termux username (e.g., u0_a123): " MANUAL_USER
    if [ -n "$MANUAL_USER" ]; then
        USER_ID="$MANUAL_USER"
        if ssh -p 8022 -o StrictHostKeyChecking=no -o ConnectTimeout=3 "$USER_ID@192.168.0.210" "echo Connected" &>/dev/null; then
            log_message "${GREEN}✓ Connected successfully with user $USER_ID${NC}"
            USER_FOUND=true
        else
            log_message "${RED}✗ Could not connect with user $USER_ID${NC}"
            exit 1
        fi
    else
        log_message "No username provided. Exiting."
        exit 1
    fi
fi

# Create a temporary directory for scripts
TEMP_DIR=$(mktemp -d)
SETUP_SCRIPT="$TEMP_DIR/setup_a50.sh"

# Create the setup script for the Samsung A50
log_message "Creating mobile device setup script..."
cat > "$SETUP_SCRIPT" << EOL
#!/data/data/com.termux/files/usr/bin/bash
# Samsung A50 Docker Swarm Worker Setup Script
# Generated by add_samsung_a50.sh on $(date)

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "\${BLUE}===================================================\${NC}"
echo -e "\${BLUE}   SAMSUNG A50 DOCKER SWARM SETUP                  \${NC}"
echo -e "\${BLUE}===================================================\${NC}"
echo

# Function to install packages
install_packages() {
    echo -e "\${YELLOW}Installing required packages...\${NC}"
    pkg update -y
    pkg install -y python termux-api wget curl proot-distro
    echo -e "\${GREEN}✓ Basic packages installed\${NC}"
}

# Function to set up Ubuntu in Termux
setup_ubuntu() {
    echo -e "\${YELLOW}Setting up Ubuntu in Termux...\${NC}"
    
    # Install proot-distro if not already installed
    if ! command -v proot-distro &> /dev/null; then
        pkg install -y proot-distro
    fi
    
    # Install Ubuntu
    proot-distro install ubuntu
    
    echo -e "\${GREEN}✓ Ubuntu installed\${NC}"
    
    # Create a script to install Docker in Ubuntu
    echo -e "\${YELLOW}Creating Docker installation script...\${NC}"
    mkdir -p ~/ubuntu-files
    cat > ~/ubuntu-files/install_docker.sh << EOF
#!/bin/bash
apt update
apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=arm64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install -y docker-ce docker-ce-cli containerd.io

# Add current user to docker group
usermod -aG docker \$(whoami)

# Start Docker service
mkdir -p /etc/docker
echo '{"hosts": ["tcp://0.0.0.0:2375", "unix:///var/run/docker.sock"]}' > /etc/docker/daemon.json
dockerd > /dev/null 2>&1 &

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo "Docker installation complete"
EOF
    chmod +x ~/ubuntu-files/install_docker.sh
    
    # Run the Docker installation script in Ubuntu
    echo -e "\${YELLOW}Installing Docker in Ubuntu...\${NC}"
    proot-distro login ubuntu -- bash -c "bash /home/\$(whoami)/ubuntu-files/install_docker.sh"
    
    echo -e "\${GREEN}✓ Docker installed in Ubuntu\${NC}"
}

# Function to create launcher script
create_launcher() {
    echo -e "\${YELLOW}Creating launcher scripts...\${NC}"
    
    # Create script to start Docker environment
    cat > ~/start-docker.sh << EOF
#!/data/data/com.termux/files/usr/bin/bash
echo "Starting Docker environment..."
termux-wake-lock
proot-distro login ubuntu -- bash -c "dockerd > /dev/null 2>&1 &"
sleep 5
echo "Docker environment started"
EOF
    chmod +x ~/start-docker.sh
    
    # Create script to join Docker Swarm
    cat > ~/join-swarm.sh << EOF
#!/data/data/com.termux/files/usr/bin/bash
echo "Joining Docker Swarm..."
proot-distro login ubuntu -- bash -c "docker swarm join --token $JOIN_TOKEN 192.168.0.200:2377"
echo "Swarm join command executed"
EOF
    chmod +x ~/join-swarm.sh
    
    echo -e "\${GREEN}✓ Launcher scripts created\${NC}"
}

# Main installation process
echo -e "\${YELLOW}Starting setup process...\${NC}"

# Install basic packages
install_packages

# Setup Ubuntu with Docker
setup_ubuntu

# Create launcher scripts
create_launcher

echo
echo -e "\${GREEN}===================================================\${NC}"
echo -e "\${GREEN}   SAMSUNG A50 SETUP COMPLETE                      \${NC}"
echo -e "\${GREEN}===================================================\${NC}"
echo
echo -e "To start Docker: \${YELLOW}./start-docker.sh\${NC}"
echo -e "To join the swarm: \${YELLOW}./join-swarm.sh\${NC}"
echo
echo -e "\${YELLOW}Starting Docker service now...\${NC}"
~/start-docker.sh
sleep 10
echo -e "\${YELLOW}Joining Docker Swarm...\${NC}"
~/join-swarm.sh

echo -e "\${GREEN}Setup complete!\${NC}"
EOL

# Copy the setup script to the Samsung A50
log_message "Copying setup script to Samsung A50..."
scp -P 8022 -o StrictHostKeyChecking=no "$SETUP_SCRIPT" "$USER_ID@192.168.0.210:~/setup_a50.sh" 2>/dev/null

if [ $? -eq 0 ]; then
    log_message "${GREEN}✓ Successfully copied script to Samsung A50${NC}"
    
    # Make the script executable
    ssh -p 8022 -o StrictHostKeyChecking=no "$USER_ID@192.168.0.210" "chmod +x ~/setup_a50.sh" 2>/dev/null
    
    # Execute the script remotely
    log_message "Executing setup script on Samsung A50..."
    log_message "${YELLOW}This may take some time. Please be patient...${NC}"
    
    ssh -p 8022 -o StrictHostKeyChecking=no "$USER_ID@192.168.0.210" "~/setup_a50.sh" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log_message "${GREEN}✓ Setup script execution initiated${NC}"
        
        # Setup will continue in the background on the mobile device
        log_message "Setup is continuing on the Samsung A50"
        log_message "It may take up to 10 minutes to complete the full installation"
    else
        log_message "${RED}✗ Failed to execute setup script${NC}"
        log_message "${YELLOW}⚠ You may need to run the script manually on the Samsung A50${NC}"
        log_message "Connect to the Samsung A50 using:"
        log_message "ssh -p 8022 $USER_ID@192.168.0.210"
        log_message "Then run: ~/setup_a50.sh"
    fi
else
    log_message "${RED}✗ Failed to copy script to Samsung A50${NC}"
    exit 1
fi

# Create a monitor script to check the status of the Samsung A50
log_message "Creating Samsung A50 monitoring script..."

MONITOR_SCRIPT="/home/optiplex_780_1/Desktop/BlueprintProject/scripts/monitor_samsung_a50.sh"
cat > "$MONITOR_SCRIPT" << EOL
#!/bin/bash

# Samsung A50 Monitoring Script for Docker Swarm Cluster
# This script checks the status of the Samsung A50 in the Docker Swarm cluster

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}     SAMSUNG A50 DOCKER SWARM STATUS               ${NC}"
echo -e "${BLUE}====================================================${NC}"
echo

# Check if Samsung A50 is reachable
echo -e "${YELLOW}Checking if Samsung A50 is reachable...${NC}"
if ping -c 1 -W 2 192.168.0.210 &> /dev/null; then
    echo -e "${GREEN}✓ Samsung A50 is reachable at 192.168.0.210${NC}"
    
    # Check if SSH is running
    if nc -z -w 5 192.168.0.210 8022; then
        echo -e "${GREEN}✓ SSH service is running on Samsung A50${NC}"
        
        # Try to connect to the Samsung A50
        for USER_PREFIX in "u0_a" "shell" "root"; do
            for i in {10..200}; do
                USER_ID="\${USER_PREFIX}\${i}"
                
                # Try to connect and check Docker status
                if ssh -p 8022 -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes "\$USER_ID@192.168.0.210" "echo Connected" &>/dev/null; then
                    echo -e "${GREEN}✓ Connected successfully with user \$USER_ID${NC}"
                    
                    # Check if Docker is running in Ubuntu
                    DOCKER_STATUS=\$(ssh -p 8022 -o StrictHostKeyChecking=no "\$USER_ID@192.168.0.210" "proot-distro login ubuntu -- docker info 2>/dev/null | grep 'Server Version'" || echo "Not running")
                    
                    if [ "\$DOCKER_STATUS" != "Not running" ]; then
                        echo -e "${GREEN}✓ Docker is running on Samsung A50${NC}"
                        echo -e "Docker version: \$DOCKER_STATUS"
                        
                        # Check swarm status
                        SWARM_STATUS=\$(ssh -p 8022 -o StrictHostKeyChecking=no "\$USER_ID@192.168.0.210" "proot-distro login ubuntu -- docker info 2>/dev/null | grep 'Swarm: '" || echo "Swarm: inactive")
                        
                        if [[ "\$SWARM_STATUS" == *"active"* ]]; then
                            echo -e "${GREEN}✓ Samsung A50 is part of the Docker Swarm${NC}"
                        else
                            echo -e "${YELLOW}⚠ Samsung A50 is not part of the Docker Swarm${NC}"
                            echo -e "To join the swarm, connect to the Samsung A50 and run:"
                            echo -e "ssh -p 8022 \$USER_ID@192.168.0.210"
                            echo -e "Then run: ~/join-swarm.sh"
                        fi
                    else
                        echo -e "${YELLOW}⚠ Docker is not running on Samsung A50${NC}"
                        echo -e "To start Docker, connect to the Samsung A50 and run:"
                        echo -e "ssh -p 8022 \$USER_ID@192.168.0.210"
                        echo -e "Then run: ~/start-docker.sh"
                    fi
                    
                    break 2
                fi
            done
        done
    else
        echo -e "${RED}✗ SSH service not detected on Samsung A50${NC}"
        echo -e "Please ensure the SSH server is running in Termux:"
        echo -e "In Termux, run: sshd"
    fi
else
    echo -e "${RED}✗ Samsung A50 not reachable at 192.168.0.210${NC}"
    echo -e "Please ensure the Samsung A50 is connected to Wi-Fi with IP 192.168.0.210"
fi

echo -e "${BLUE}====================================================${NC}"
EOL

chmod +x "$MONITOR_SCRIPT"

# Create desktop shortcut for monitoring
log_message "Creating desktop shortcut for Samsung A50 monitoring..."
SHORTCUT_FILE="/home/optiplex_780_1/Desktop/Monitor_Samsung_A50.desktop"

cat > "$SHORTCUT_FILE" << EOL
[Desktop Entry]
Type=Application
Terminal=true
Name=Monitor Samsung A50
Exec=$MONITOR_SCRIPT
Icon=utilities-terminal
Comment=Check the status of the Samsung A50 in the Docker Swarm cluster
Path=/home/optiplex_780_1/Desktop
EOL

chmod +x "$SHORTCUT_FILE"

# Clean up
rm -rf "$TEMP_DIR"

log_message "${GREEN}✓ Samsung A50 integration process initiated${NC}"
log_message "Please wait for the setup to complete on the Samsung A50"
log_message "To check the status, use the Monitor_Samsung_A50 desktop shortcut"
echo -e "${BLUE}====================================================${NC}"
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
