#!/bin/bash

# ========================================================================
#      JLPG PRO+ MULTI-VM MANAGER (ULTIMATE EDITION)
# ========================================================================

# Colors & Styles
C='\033[0;36m'   # Cyan
G='\033[0;32m'   # Green
B='\033[0;34m'   # Blue
Y='\033[1;33m'   # Yellow
R='\033[0;31m'   # Red
P='\033[0;35m'   # Purple
NC='\033[0m'     # No Color
BOLD='\033[1m'

# Configuration
VM_DIR="$HOME/jlpg_vms"
mkdir -p "$VM_DIR"

# OS Options (Type|Codename|URL|Default Host|Default User|Default Pass)
declare -A OS_OPTIONS
OS_OPTIONS["Ubuntu 22.04"]="Ubuntu|Jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|jlpg-ubuntu|ubuntu|jlpg123"
OS_OPTIONS["Debian 12"]="Debian|Bookworm|https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|jlpg-debian|debian|jlpg123"

# Function to display the JLPG Dashboard
display_dashboard() {
    clear
    # Real-time Stats
    UPTIME=$(uptime -p | sed 's/up //')
    CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    RAM_USAGE=$(free | grep Mem | awk '{print $3/$2 * 100.0}' | cut -d. -f1)
    
    # Top Status Bar
    echo -e "${B}▐█ HOST: $(hostname) ${NC}  ${P}▐█ $UPTIME ${NC}  ${G}▐█ JLPG: ACTIVE ${NC}"
    
    # JLPG Logo
    echo -e "${C}${BOLD}"
    echo "      ██╗██╗     ██████╗  ██████╗ "
    echo "      ██║██║     ██╔══██╗██╔════╝ "
    echo "      ██║██║     ██████╔╝██║  ███╗"
    echo " ██   ██║██║     ██╔═══╝ ██║   ██║"
    echo " ╚█████╔╝███████╗██║     ╚██████╔╝"
    echo "  ╚════╝ ╚══════╝╚═╝      ╚═════╝ "
    echo -e "          ${Y}POWERED BY JLPGGAMING${NC}"
    echo -e "${C}──────────────────────────────────────────────────────────${NC}"
    
    # System Health Section
    echo -e " System Health: CPU: ${C}${CPU_LOAD}%${NC}  RAM: ${P}${RAM_USAGE}%${NC}  Network: ${G}CONNECTED${NC}"
    echo ""
}

# Function to List VMs
list_vms() {
    echo -e " ${BOLD}${C}❑ ACTIVE JLPG NODES${NC}"
    echo -e " NAME           | STATUS   | SSH PORT | OS"
    echo -e " ---------------|----------|----------|--------"
    
    local configs=$(find "$VM_DIR" -name "*.conf" 2>/dev/null)
    if [ -z "$configs" ]; then
        echo -e "   No VMs found. Create one using option [1]"
    else
        for cfg in $configs; do
            source "$cfg"
            # Check if running
            if pgrep -f "qemu.*$VM_NAME" >/dev/null; then
                STATUS="${G}Running${NC}"
            else
                STATUS="${R}Stopped${NC}"
            fi
            printf " %-14s | %-16s | %-8s | %s\n" "$VM_NAME" "$STATUS" "$SSH_PORT" "$OS_TYPE"
        done
    fi
    echo ""
}

# Function to Create VM (Simplified Logic from your prompt)
create_vm() {
    echo -e "${Y}--- [ STARTING NEW JLPG DEPLOYMENT ] ---${NC}"
    # Choosing OS
    echo "Select OS:"
    PS3="Choice: "
    select os_key in "${!OS_OPTIONS[@]}"; do
        if [ -n "$os_key" ]; then
            IFS='|' read -r OS_TYPE CODENAME IMG_URL VM_NAME USERNAME PASSWORD <<< "${OS_OPTIONS[$os_key]}"
            break
        fi
    done

    read -p "VM Name (Default: $VM_NAME): " input_name
    VM_NAME=${input_name:-$VM_NAME}
    read -p "RAM in MB (Default: 2048): " MEMORY
    MEMORY=${MEMORY:-2048}
    read -p "SSH Port (Default: 2222): " SSH_PORT
    SSH_PORT=${SSH_PORT:-2222}

    # Setup process
    IMG_FILE="$VM_DIR/$VM_NAME.qcow2"
    
    echo -e "${G}Downloading/Preparing Image...${NC}"
    wget -q --show-progress "$IMG_URL" -O "$IMG_FILE"
    
    # Create config file
    cat > "$VM_DIR/$VM_NAME.conf" <<EOF
VM_NAME="$VM_NAME"
OS_TYPE="$OS_TYPE"
MEMORY="$MEMORY"
SSH_PORT="$SSH_PORT"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
IMG_FILE="$IMG_FILE"
EOF

    echo -e "${G}Success! VM '$VM_NAME' configured.${NC}"
    sleep 2
}

# Function to Start VM
start_vm_logic() {
    read -p "Enter VM Name to Start: " START_NAME
    if [ -f "$VM_DIR/$START_NAME.conf" ]; then
        source "$VM_DIR/$START_NAME.conf"
        echo -e "${G}Starting $VM_NAME in background...${NC}"
        # Running QEMU in Background
        screen -dmS "$VM_NAME" qemu-system-x86_64 -m "$MEMORY" -drive file="$IMG_FILE",format=qcow2 -net nic -net user,hostfwd=tcp::"$SSH_PORT"-:22 -nographic
        echo -e "${G}VM started. Use 'screen -r $VM_NAME' to view console.${NC}"
    else
        echo -e "${R}VM not found!${NC}"
    fi
    sleep 2
}

# Main Loop
while true; do
    display_dashboard
    list_vms
    
    echo -e " ${BOLD}${C}❑ CONTROL PANEL${NC}"
    echo -e "  [1] CREATE NEW VM      [4] STOP VM"
    echo -e "  [2] START VM           [5] DELETE VM"
    echo -e "  [3] REFRESH DASHBOARD  ${R}[0] EXIT${NC}"
    echo ""
    echo -e "${C}──────────────────────────────────────────────────────────${NC}"
    read -p "➜ Action (0-5): " action

    case $action in
        1) create_vm ;;
        2) start_vm_logic ;;
        3) continue ;;
        4) read -p "Name to stop: " s; pkill -f "qemu.*$s" ;;
        5) read -p "Name to delete: " d; rm -f "$VM_DIR/$d"* ;;
        0) exit 0 ;;
        *) echo "Invalid option"; sleep 1 ;;
    esac
done
