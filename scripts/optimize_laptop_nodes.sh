#!/bin/bash
# Laptop Node Optimization Script for Docker Swarm
# This script optimizes laptop nodes for maximum performance and reliability

# Set colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print header
echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}    DOCKER SWARM LAPTOP NODE OPTIMIZATION    ${NC}"
echo -e "${BLUE}=====================================================${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}This script must be run as root (use sudo)${NC}"
  exit 1
fi

# Function to optimize an HP laptop node
optimize_hp_laptop() {
  local IP="$1"
  echo -e "${YELLOW}Optimizing HP laptop node at $IP...${NC}"

  # SSH into the HP laptop and perform optimizations
  ssh optiplex_780_1@$IP "sudo -S bash -c '
    # Update system packages
    echo \"Updating system packages...\"
    apt-get update
    apt-get upgrade -y
    
    # Install necessary utilities
    echo \"Installing utilities...\"
    apt-get install -y clamav clamav-daemon rkhunter htop iotop powertop tlp
    
    # Update graphics drivers
    echo \"Updating graphics drivers...\"
    ubuntu-drivers autoinstall
    
    # Check and update firmware using fwupd
    echo \"Checking for firmware updates...\"
    apt-get install -y fwupd
    fwupdmgr refresh
    fwupdmgr get-updates
    fwupdmgr update
    
    # Configure laptop to keep running when lid is closed
    echo \"Configuring laptop to run with lid closed...\"
    sed -i \"s/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/g\" /etc/systemd/logind.conf
    sed -i \"s/#HandleLidSwitchExternalPower=suspend/HandleLidSwitchExternalPower=ignore/g\" /etc/systemd/logind.conf
    sed -i \"s/#HandleLidSwitchDocked=ignore/HandleLidSwitchDocked=ignore/g\" /etc/systemd/logind.conf
    systemctl restart systemd-logind
    
    # Optimize power settings for better performance
    echo \"Optimizing power settings...\"
    apt-get install -y tlp tlp-rdw
    tlp start
    
    # Set CPU governor to performance when on AC power
    echo \"Setting CPU governor for AC power...\"
    echo \"performance\" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
    
    # Enable hardware acceleration
    echo \"Enabling hardware acceleration...\"
    apt-get install -y vainfo
    
    # Run security scans
    echo \"Running security scans...\"
    freshclam
    clamscan --recursive --infected /home
    rkhunter --update
    rkhunter --check --skip-keypress
    
    # Configure Docker for optimal performance
    echo \"Optimizing Docker settings...\"
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << DOCKERCONFIG
{
  \"log-driver\": \"json-file\",
  \"log-opts\": {
    \"max-size\": \"10m\",
    \"max-file\": \"3\"
  },
  \"default-shm-size\": \"64M\",
  \"storage-driver\": \"overlay2\",
  \"metrics-addr\": \"0.0.0.0:9323\",
  \"experimental\": true
}
DOCKERCONFIG
    systemctl restart docker
    
    # Add docker configuration for resource limits
    echo \"Configuring Docker resource limits...\"
    mkdir -p /etc/systemd/system/docker.service.d
    cat > /etc/systemd/system/docker.service.d/override.conf << OVERRIDE
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --default-cpu-quota 50000 --default-cpu-period 100000 --default-memory-limit 4G
OVERRIDE
    systemctl daemon-reload
    systemctl restart docker
    
    echo \"Optimization completed!\"
  '"
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ HP laptop node at $IP has been optimized${NC}"
  else
    echo -e "${RED}✗ Failed to optimize HP laptop node at $IP${NC}"
  fi
}

# Function to optimize a Lenovo laptop node running Windows with Docker Desktop
optimize_lenovo_laptop() {
  local IP="$1"
  echo -e "${YELLOW}Optimizing Lenovo laptop node at $IP...${NC}"
  
  # First, let's create a PowerShell script to run on the Windows machine
  cat > /tmp/optimize_lenovo_laptop.ps1 << 'EOF'
# PowerShell script to optimize Lenovo laptop for Docker Swarm
Write-Host "Starting Lenovo laptop optimization for Docker Swarm..."

# Function to check if running as Administrator
function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    $principal = New-Object Security.Principal.WindowsPrincipal $user
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Host "This script must be run as Administrator. Please restart as Administrator."
    Exit 1
}

# Update Windows
Write-Host "Checking for Windows updates..."
Install-Module -Name PSWindowsUpdate -Force
Import-Module PSWindowsUpdate
Get-WindowsUpdate -Install -AcceptAll -IgnoreReboot

# Install necessary utilities
Write-Host "Installing necessary utilities..."
choco install -y malwarebytes avastfreeantivirus rkhunter hwinfo nvcleanstall

# Update drivers
Write-Host "Updating drivers..."
choco install -y lenovo-thinkvantage-system-update
Start-Process -FilePath "C:\Program Files (x86)\Lenovo\System Update\tvsu.exe" -ArgumentList "/CM" -Wait

# Check for firmware updates
Write-Host "Checking for firmware updates..."
choco install -y lenovo-firmware-winpe
& "C:\Program Files (x86)\Lenovo\System Update\tvsu.exe" /CM

# Configure power settings for performance
Write-Host "Configuring power settings..."
powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c  # High Performance
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /change disk-timeout-ac 0
powercfg /change monitor-timeout-ac 30

# Configure laptop to keep running when lid is closed
Write-Host "Configuring laptop to run with lid closed..."
powercfg -setacvalueindex 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 0
powercfg -setdcvalueindex 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 0

# Run security scans
Write-Host "Running security scans..."
Start-Process -FilePath "C:\Program Files\Malwarebytes\Anti-Malware\mb3.exe" -ArgumentList "/scan" -Wait
Start-Process -FilePath "C:\Program Files\Avast Software\Avast\avcli.exe" -ArgumentList "/scan:quick" -Wait

# Optimize Docker Desktop settings
Write-Host "Optimizing Docker Desktop settings..."
$dockerConfigPath = "$env:USERPROFILE\.docker\daemon.json"
$dockerConfig = @{
    "log-driver" = "json-file"
    "log-opts" = @{
        "max-size" = "10m"
        "max-file" = "3"
    }
    "storage-driver" = "overlay2"
    "metrics-addr" = "0.0.0.0:9323"
    "experimental" = $true
}

# Create directory if it doesn't exist
if (-not (Test-Path (Split-Path $dockerConfigPath))) {
    New-Item -ItemType Directory -Path (Split-Path $dockerConfigPath) -Force
}

# Write configuration to file
$dockerConfig | ConvertTo-Json | Set-Content $dockerConfigPath

# Configure Docker Desktop resource limits
$dockerDesktopConfigPath = "$env:APPDATA\Docker\settings.json"
$dockerDesktopConfig = Get-Content $dockerDesktopConfigPath | ConvertFrom-Json
$dockerDesktopConfig.cpus = 4
$dockerDesktopConfig.memoryMiB = 4096
$dockerDesktopConfig.swapMiB = 1024
$dockerDesktopConfig | ConvertTo-Json -Depth 10 | Set-Content $dockerDesktopConfigPath

# Configure Docker Desktop to start with Windows
Write-Host "Configuring Docker Desktop to start with Windows..."
$startupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$dockerDesktopPath = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
$shortcutPath = "$startupFolder\Docker Desktop.lnk"

$WScriptShell = New-Object -ComObject WScript.Shell
$shortcut = $WScriptShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $dockerDesktopPath
$shortcut.WorkingDirectory = Split-Path $dockerDesktopPath
$shortcut.Description = "Docker Desktop"
$shortcut.Save()

# Set WSL to start automatically
Write-Host "Configuring WSL to start automatically..."
$wslStartupScript = @"
@echo off
wsl --set-default-version 2
wsl -u root service docker start
"@
$wslStartupScript | Set-Content "$startupFolder\start-wsl.bat"

Write-Host "Lenovo laptop optimization completed!"
Write-Host "Please restart Docker Desktop and the computer for changes to take effect."
EOF

  # Copy the PowerShell script to the Lenovo laptop
  scp /tmp/optimize_lenovo_laptop.ps1 optiplex_780_1@$IP:/tmp/

  # Execute the PowerShell script remotely
  ssh optiplex_780_1@$IP "powershell -ExecutionPolicy Bypass -File /tmp/optimize_lenovo_laptop.ps1"
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Lenovo laptop node at $IP has been optimized${NC}"
  else
    echo -e "${RED}✗ Failed to optimize Lenovo laptop node at $IP${NC}"
  fi
  
  # Clean up
  rm /tmp/optimize_lenovo_laptop.ps1
}

# Main menu for node selection
echo -e "${YELLOW}Select the laptop node to optimize:${NC}"
echo -e "1) HP Laptop (192.168.0.204)"
echo -e "2) Lenovo Laptop (192.168.0.205)"
echo -e "3) Both laptops"
echo -e "4) Exit"

read -p "Enter your choice (1-4): " choice

case $choice in
  1)
    optimize_hp_laptop "192.168.0.204"
    ;;
  2)
    optimize_lenovo_laptop "192.168.0.205"
    ;;
  3)
    optimize_hp_laptop "192.168.0.204"
    optimize_lenovo_laptop "192.168.0.205"
    ;;
  4)
    echo -e "${YELLOW}Exiting without optimization${NC}"
    exit 0
    ;;
  *)
    echo -e "${RED}Invalid choice${NC}"
    exit 1
    ;;
esac

echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}    LAPTOP NODE OPTIMIZATION COMPLETE    ${NC}"
echo -e "${BLUE}=====================================================${NC}"
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
