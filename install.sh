#!/bin/bash
set -euo pipefail

# --- JLPG Branding & Colors ---
C='\033[0;36m'   # Cyan
G='\033[0;32m'   # Green
B='\033[0;34m'   # Blue
Y='\033[1;33m'   # Yellow
R='\033[0;31m'   # Red
P='\033[0;35m'   # Purple
NC='\033[0m'     # No Color
BOLD='\033[1m'

# --- Configuration & Directories ---
VM_DIR="$HOME/jlpg_vms"
mkdir -p "$VM_DIR"

# OS Options (Aapke logic ke hisaab se)
declare -A OS_OPTIONS
OS_OPTIONS["Ubuntu 22.04"]="Ubuntu|Jammy|https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img|jlpg-ubuntu|ubuntu|jlpg123"
OS_OPTIONS["Debian 12"]="Debian|Bookworm|https://cdimage.debian.org/cdimage/cloud/bookworm/latest/debian-12-generic-amd64.qcow2|jlpg-debian|debian|jlpg123"

# --- Function: Professional Dashboard ---
draw_ui() {
    clear
    UPTIME=$(uptime -p | sed 's/up //')
    CPU_LOAD=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    RAM_USAGE=$(free | grep Mem | awk '{print $3/$2 * 100.0}' | cut -d. -f1)
    
    # Top Status Bar (Exactly like your Screenshot)
    echo -e "${B}▐█ HOST: $(hostname) ${NC}  ${P}▐█ $UPTIME ${NC}  ${G}▐█ RAM: $RAM_USAGE% ${NC}  ${C}▐█ JLPG: ACTIVE ${NC}"
    
    # JLPG Logo (New ASCII)
    echo -e "${C}${BOLD}"
    echo "      ██╗██╗     ██████╗  ██████╗ "
    echo "      ██║██║     ██╔══██╗██╔════╝ "
    echo "      ██║██║     ██████╔╝██║  ███╗"
    echo " ██   ██║██║     ██╔═══╝ ██║   ██║"
    echo " ╚█████╔╝███████╗██║     ╚██████╔╝"
    echo "  ╚════╝ ╚══════╝╚═╝      ╚═════╝ "
    echo -e "          ${Y}POWERED BY JLPGGAMING${NC}"
    echo -e "${C}──────────────────────────────────────────────────────────${NC}"
    
    # Active Nodes List
    echo -e " ${BOLD}${C}❑ ACTIVE JLPG NODES${NC}"
    echo -e " NAME           | STATUS   | SSH PORT | RAM"
    echo -e " ---------------|----------|----------|--------"
    
    configs=$(find "$VM_DIR" -name "*.conf" 2>/dev/null)
    if [ -z "$configs" ]; then
        echo -e "   No Active Nodes found. Create one [1]"
    else
        for cfg in $configs; do
            source "$cfg"
            if pgrep -f "qemu.*$VM_NAME" >/dev/null; then
                STATUS="${G}Running${NC}"
            else
                STATUS="${R}Stopped${NC}"
            fi
            printf " %-14s | %-16s | %-8s | %s\n" "$VM_NAME" "$STATUS" "$SSH_PORT" "$MEMORY"
        done
    fi
    echo ""
    echo -e " System Health: CPU: ${C}${CPU_LOAD}%${NC}  RAM: ${P}${RAM_USAGE}%${NC}  Disk: ${G}$(df -h / | awk 'NR==2 {print $5}')${NC}"
    echo ""
}

# --- Function: Create VM with Cloud-Init (Full Working) ---
create_vm_logic() {
    echo -e "${Y}--- NEW JLPG DEPLOYMENT ---${NC}"
    
    # OS Selection
    echo -e "Select an OS to set up:"
    local i=1
    local os_list=()
    for os in "${!OS_OPTIONS[@]}"; do
        echo "  $i) $os"
        os_list[$i]="$os"
        ((i++))
    done
    read -p "Enter Choice: " os_choice
    local selected_os="${os_list[$os_choice]}"
    
    IFS='|' read -r OS_TYPE CODENAME IMG_URL DEFAULT_NAME USERNAME PASSWORD <<< "${OS_OPTIONS[$selected_os]}"
    
    read -p "VM Name (Default: $DEFAULT_NAME): " VM_NAME
    VM_NAME=${VM_NAME:-$DEFAULT_NAME}
    read -p "RAM in MB (Default: 2048): " MEMORY
    MEMORY=${MEMORY:-2048}
    read -p "SSH Port (Default: 2222): " SSH_PORT
    SSH_PORT=${SSH_PORT:-2222}
    read -p "Disk Size (Default: 20G): " DISK_SIZE
    DISK_SIZE=${DISK_SIZE:-20G}

    IMG_FILE="$VM_DIR/$VM_NAME.qcow2"
    SEED_FILE="$VM_DIR/$VM_NAME-seed.iso"

    # Download Image
    if [ ! -f "$IMG_FILE" ]; then
        echo -e "${G}Downloading $OS_TYPE Cloud Image...${NC}"
        wget -q --show-progress "$IMG_URL" -O "$IMG_FILE"
        qemu-img resize "$IMG_FILE" "$DISK_SIZE"
    fi

    # Cloud-Init Config (User Data)
    cat > user-data <<EOF
#cloud-config
hostname: $VM_NAME
manage_etc_hosts: true
users:
  - name: $USERNAME
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: $(openssl passwd -6 "$PASSWORD")
ssh_pwauth: true
EOF
    echo "instance-id: $VM_NAME" > meta-data

    # Generate Seed ISO
    cloud-localds "$SEED_FILE" user-data meta-data
    rm user-data meta-data

    # Save Config
    cat > "$VM_DIR/$VM_NAME.conf" <<EOF
VM_NAME="$VM_NAME"
MEMORY="$MEMORY"
SSH_PORT="$SSH_PORT"
IMG_FILE="$IMG_FILE"
SEED_FILE="$SEED_FILE"
EOF

    echo -e "${G}Node $VM_NAME is ready to launch!${NC}"
    sleep 2
}

# --- Main Logic ---
while true; do
    draw_ui
    echo -e " ${BOLD}${C}❑ DEPLOYMENT SERVICES${NC}"
    echo -e "  [1] CREATE VPS         [5] THEME (Soon)"
    echo -e "  [2] START VPS          [6] EDIT SCRIPT"
    echo -e "  [3] STOP VPS           [7] CONTAINER"
    echo ""
    echo -e " ${BOLD}${C}❑ MAINTENANCE${NC}"
    echo -e "  [4] VM LIST            ${R}[0] SHUTDOWN${NC}"
    echo ""
    echo -e "${C}──────────────────────────────────────────────────────────${NC}"
    read -p "➜ Master Action (0-7): " choice

    case $choice in
        1) create_vm_logic ;;
        2) 
            read -p "Enter VM Name: " sname
            if [ -f "$VM_DIR/$sname.conf" ]; then
                source "$VM_DIR/$sname.conf"
                screen -dmS "$VM_NAME" qemu-system-x86_64 -m "$MEMORY" -smp 2 \
                -drive file="$IMG_FILE",format=qcow2 -drive file="$SEED_FILE",format=raw \
                -net nic -net user,hostfwd=tcp::"$SSH_PORT"-:22 -nographic
                echo -e "${G}Node $VM_NAME is starting in background...${NC}"
            fi
            sleep 1 ;;
        3) read -p "Enter Name to Stop: " stname; pkill -f "qemu.*$stname"; sleep 1 ;;
        4) clear; virsh list --all 2>/dev/null || echo "No libvirt VMs"; read -p "Press Enter...";;
        6) nano $0 ;;
        0) exit 0 ;;
        *) echo "Invalid Action"; sleep 1 ;;
    esac
done
