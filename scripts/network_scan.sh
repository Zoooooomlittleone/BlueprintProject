#!/bin/bash

# Network Scanner Script
# This script scans a range of IP addresses and reports which ones are active

# Terminal colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}     NETWORK SCANNER                                ${NC}"
echo -e "${BLUE}====================================================${NC}"
echo

# Define the network range to scan
NETWORK="192.168.0"
START_IP=1
END_IP=254

# Create a temporary file for storing results
TEMP_FILE=$(mktemp)

echo -e "${YELLOW}Scanning network range ${NETWORK}.${START_IP} - ${NETWORK}.${END_IP}...${NC}"
echo -e "This may take some time. Please wait...\n"

# Track progress
TOTAL_IPS=$((END_IP - START_IP + 1))
PROGRESS=0
FOUND_DEVICES=0

# Function to update progress
update_progress() {
    PROGRESS=$((PROGRESS + 1))
    PERCENT=$((PROGRESS * 100 / TOTAL_IPS))
    
    # Update progress every 10 IPs to avoid cluttering the terminal
    if [ $((PROGRESS % 10)) -eq 0 ] || [ $PROGRESS -eq $TOTAL_IPS ]; then
        echo -ne "Progress: ${PERCENT}% (${PROGRESS}/${TOTAL_IPS})\r"
    fi
}

# Scan each IP in the range
for i in $(seq $START_IP $END_IP); do
    IP="${NETWORK}.${i}"
    
    # Use ping with a timeout to check if the IP is active
    ping -c 1 -W 1 $IP > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        # IP is active
        FOUND_DEVICES=$((FOUND_DEVICES + 1))
        
        # Try to get hostname using nslookup or nbtscan if available
        HOSTNAME=$(nslookup $IP 2>/dev/null | grep "name =" | awk '{print $4}' | sed 's/\.$//' || echo "Unknown")
        
        # If nslookup didn't work, try using arp to get MAC address
        if [ "$HOSTNAME" = "Unknown" ]; then
            MAC=$(arp -n | grep "$IP " | awk '{print $3}')
            MANUFACTURER=""
            
            # Try to identify device by MAC address OUI (Organizational Unique Identifier)
            if [ -n "$MAC" ]; then
                OUI=${MAC:0:8}
                case $OUI in
                    "b8:27:eb") MANUFACTURER="Raspberry Pi" ;;
                    "00:50:56") MANUFACTURER="VMware" ;;
                    "52:54:00") MANUFACTURER="QEMU/KVM" ;;
                    "00:1a:11") MANUFACTURER="Google" ;;
                    "e4:5f:01") MANUFACTURER="Hewlett Packard" ;;
                    "68:f7:28") MANUFACTURER="Lenovo" ;;
                    "00:24:9b") MANUFACTURER="Huawei" ;;
                    "b0:5c:e5") MANUFACTURER="Nokia" ;;
                    "00:50:c2") MANUFACTURER="Samsung" ;;
                    *) MANUFACTURER="" ;;
                esac
            fi
            
            if [ -n "$MANUFACTURER" ]; then
                HOSTNAME="Unknown ($MANUFACTURER device)"
            fi
        fi
        
        echo -e "$IP\t$HOSTNAME\t$(arp -n | grep "$IP " | awk '{print $3}')" >> $TEMP_FILE
    fi
    
    update_progress
done

echo -e "\n\n${GREEN}✓ Scan complete!${NC}"
echo -e "${GREEN}✓ Found ${FOUND_DEVICES} active devices${NC}\n"

echo -e "${BOLD}Active devices:${NC}"
echo -e "${BOLD}IP Address\tHostname\tMAC Address${NC}"
echo -e "--------------------------------------------------------"
sort -t . -k 4,4n $TEMP_FILE

# Clean up
rm $TEMP_FILE

echo -e "\n${YELLOW}Looking for devices similar to HP laptops...${NC}"
HP_MACS=$(sort -t . -k 4,4n $TEMP_FILE | grep -i -E "hewlett|hp|e4:5f" || echo "None found")
if [ "$HP_MACS" != "None found" ]; then
    echo -e "${GREEN}Possible HP devices:${NC}"
    echo -e "$HP_MACS"
else
    echo -e "${YELLOW}No devices specifically identified as HP were found${NC}"
    echo -e "This doesn't mean the HP laptop isn't present - it may just not have an identifiable MAC prefix"
fi

echo -e "\n${YELLOW}Looking for devices at IP 192.168.0.206...${NC}"
if ping -c 1 -W 1 192.168.0.206 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Device at 192.168.0.206 is online${NC}"
    echo -e "MAC Address: $(arp -n | grep "192.168.0.206" | awk '{print $3}')"
    echo -e "This could be your HP laptop. Let's check if it has SSH and/or Docker running."
    
    # Try SSH connection to check if it's a computer
    echo -e "\nTrying SSH connection..."
    for USER in "Administrator" "admin" "user"; do
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -o BatchMode=yes "$USER@192.168.0.206" "echo Connected" &>/dev/null; then
            echo -e "${GREEN}✓ SSH connection successful with user: $USER${NC}"
            
            # If it's a Windows machine, check for Docker
            if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 "$USER@192.168.0.206" "powershell -Command \"Get-Service -Name docker 2>/dev/null\"" &>/dev/null; then
                echo -e "${GREEN}✓ Docker service found on 192.168.0.206${NC}"
                echo -e "${GREEN}=> This is very likely your HP laptop${NC}"
            else
                echo -e "${YELLOW}Docker service not found or not accessible${NC}"
                echo -e "This could still be your HP laptop, but Docker might not be installed or accessible"
            fi
            break
        fi
    done
else
    echo -e "${RED}✗ No device found at 192.168.0.206${NC}"
    echo -e "The HP laptop might be at a different IP address or currently offline"
fi

echo -e "\n${BLUE}====================================================${NC}"
echo -e "${BLUE}     SCAN COMPLETE                                  ${NC}"
echo -e "${BLUE}====================================================${NC}"
echo
echo -e "If you identified the correct IP for your HP laptop and it's different from 192.168.0.206,"
echo -e "you'll need to update the configuration in these scripts:"
echo -e "1. /home/optiplex_780_1/Desktop/BlueprintProject/scripts/node_startup.sh"
echo -e "2. /home/optiplex_780_1/Desktop/BlueprintProject/scripts/node_shutdown.sh"
echo -e "3. /home/optiplex_780_1/Desktop/BlueprintProject/scripts/add_hp_laptop.sh"
echo -e "4. /home/optiplex_780_1/Desktop/BlueprintProject/scripts/test_all_nodes.sh"
# ORGANIZED: Copy stored in ~/cluster-scripts/[category]
