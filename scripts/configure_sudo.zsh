#!/bin/bash
set -e  # Exit immediately if any command returns a non-zero status

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'  # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${PURPLE}==>${NC} ${CYAN}$1${NC}"
}

# Helper functions
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -u, --user=USERNAME    Specify target user (default: detect from SUDO_USER or LOGNAME)"
    echo "  -l, --level=LEVEL      Set access level: dev, admin, root, custom"
    echo "  --show-levels          Show detailed description of access levels"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  sudo $0 -l dev              # Dev level for current user"
    echo "  sudo $0 -u alice -l admin   # Admin level for user alice"
    echo "  sudo $0 -l custom           # Custom interactive configuration"
    echo ""
    echo "⚠️  Important: This script MUST be run with sudo!"
    echo "⚠️  Security Notes:"
    echo "  • Always use the minimal required access level"
    echo "  • Review sudoers file after changes: sudo visudo -c"
    echo "  • Backup is created: /etc/sudoers.backup.DATE"
}

show_access_levels() {
    echo -e "${CYAN}Access Level Definitions:${NC}"
    echo ""
    echo -e "${YELLOW}dev${NC} - Developer Access"
    echo "  • Package management (apt, yum, dnf)"
    echo "  • Service control (systemctl start/stop/restart)"
    echo "  • Log viewing (journalctl, tail)"
    echo "  • Docker management"
    echo ""
    echo -e "${YELLOW}admin${NC} - System Administrator"
    echo "  • All 'dev' commands"
    echo "  • User management (adduser, usermod, passwd)"
    echo "  • Network configuration (ip, ifconfig, iptables)"
    echo "  • Disk management (fdisk, mount)"
    echo "  • Process management (kill, nice, renice)"
    echo ""
    echo -e "${YELLOW}root${NC} - Full Root Access (DANGEROUS)"
    echo "  • ALL commands without password"
    echo "  • Equivalent to full root access"
    echo "  • Only for isolated/trusted systems"
    echo ""
    echo -e "${YELLOW}custom${NC} - Interactive Custom Configuration"
    echo "  • Choose specific commands"
    echo "  • Set custom NOPASSWD rules"
    echo ""
    echo -e "${RED}⚠️  WARNING: root level provides COMPLETE SYSTEM ACCESS${NC}"
    echo -e "${RED}    Only use on isolated, non-production systems!${NC}"
    exit 0
}

# Security warning banner
echo -e "${RED}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║                  ⚠️  SECURITY WARNING ⚠️                       ║${NC}"
echo -e "${RED}║  Granting passwordless sudo access reduces system security!    ║${NC}"
echo -e "${RED}║  Use only in trusted environments and understand the risks!     ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Configuration
TARGET_USER=""
ACCESS_LEVEL=""
BACKUP_FILE="/etc/sudoers.backup.$(date +%Y%m%d_%H%M%S)"

# Banner
echo -e "${CYAN}"
echo "  ____  _   _ ____  _____ ____  _____ "
echo " / ___|| | | |  _ \| ____|  _ \| ____|"
echo " \___ \| | | | | | |  _| | |_) |  _|  "
echo "  ___) | |_| | |_| | |___|  _ <| |___ "
echo " |____/ \___/|____/|_____|_| \_\_____|"
echo "                                      "
echo -e "${NC}"
echo -e "${YELLOW}Passwordless Sudo Configuration Tool${NC}"
echo -e "${YELLOW}Security Levels:${NC} dev, admin, root, custom"
echo -e "${YELLOW}Warning:${NC} Use with extreme caution in production environments"
echo -e "${YELLOW}Note:${NC} Script must be run with sudo\n"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--user)
            TARGET_USER="$2"
            shift 2
            ;;
        --user=*)
            TARGET_USER="${1#*=}"
            shift
            ;;
        -l|--level)
            ACCESS_LEVEL="$2"
            shift 2
            ;;
        --level=*)
            ACCESS_LEVEL="${1#*=}"
            shift
            ;;
        --show-levels)
            show_access_levels
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Function to detect original user
detect_original_user() {
    # Try SUDO_USER first (set when using sudo)
    if [ -n "$SUDO_USER" ]; then
        echo "$SUDO_USER"
    # Try LOGNAME
    elif [ -n "$LOGNAME" ]; then
        echo "$LOGNAME"
    # Try who am i
    elif command -v who &> /dev/null; then
        who am i | awk '{print $1}'
    # Try last command
    elif command -v last &> /dev/null; then
        last -1 | awk 'NR==1{print $1}'
    else
        # Fallback to checking /proc
        if [ -f "/proc/$$/loginuid" ]; then
            login_uid=$(cat /proc/$$/loginuid 2>/dev/null)
            if [ -n "$login_uid" ] && [ "$login_uid" != "4294967295" ]; then
                getent passwd "$login_uid" | cut -d: -f1
            fi
        fi
    fi
}

# Validate and set parameters
validate_parameters() {
    # Set target user if not specified
    if [ -z "$TARGET_USER" ]; then
        ORIGINAL_USER=$(detect_original_user)
        if [ -z "$ORIGINAL_USER" ]; then
            log_error "Cannot determine original user. Please specify with -u option."
            log_info "Tried: SUDO_USER='$SUDO_USER', LOGNAME='$LOGNAME'"
            log_info "Please run: sudo $0 -u YOUR_USERNAME -l LEVEL"
            exit 1
        fi
        TARGET_USER="$ORIGINAL_USER"
        log_info "Detected original user: $TARGET_USER"
    fi

    # Check if user exists
    if ! id "$TARGET_USER" &>/dev/null; then
        log_error "User '$TARGET_USER' does not exist"
        exit 1
    fi

    # Check if user is root
    if [ "$TARGET_USER" = "root" ]; then
        log_error "Cannot configure passwordless sudo for root user (already has full access)"
        exit 1
    fi

    # Validate access level
    if [ -z "$ACCESS_LEVEL" ]; then
        log_error "Access level is required. Use -l option"
        echo "Available levels: dev, admin, root, custom"
        exit 1
    fi

    case $ACCESS_LEVEL in
        dev|admin|root|custom)
            # Valid level
            ;;
        *)
            log_error "Invalid access level: $ACCESS_LEVEL"
            echo "Available levels: dev, admin, root, custom"
            exit 1
            ;;
    esac
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (use sudo)"
        echo "Please run: sudo $0 [OPTIONS]"
        exit 1
    fi
}

# Backup sudoers file
backup_sudoers() {
    log_step "1. Backup Current Configuration"
    log_info "Creating backup: $BACKUP_FILE"

    if [ -f /etc/sudoers ]; then
        cp -p /etc/sudoers "$BACKUP_FILE"
        if [ $? -eq 0 ]; then
            log_success "Backup created: $BACKUP_FILE"
        else
            log_error "Failed to backup sudoers file"
            exit 1
        fi
    else
        log_error "/etc/sudoers not found"
        exit 1
    fi
}

# Check if user is already in sudoers
check_existing_entry() {
    log_step "2. Check Existing Configuration"

    if grep -q "^$TARGET_USER" /etc/sudoers 2>/dev/null || \
       [ -f /etc/sudoers.d/$TARGET_USER ] 2>/dev/null; then
        log_warning "User $TARGET_USER already has sudo configuration"
        echo ""
        echo "Existing configuration:"
        grep "^$TARGET_USER" /etc/sudoers 2>/dev/null || true
        if [ -f /etc/sudoers.d/$TARGET_USER ]; then
            echo "File: /etc/sudoers.d/$TARGET_USER"
            cat "/etc/sudoers.d/$TARGET_USER"
        fi
        echo ""
        read -p "⚠️  Overwrite existing configuration? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Operation cancelled by user"
            exit 1
        fi
    else
        log_info "No existing sudo configuration found for $TARGET_USER"
    fi
}

# Create sudoers entry based on access level
create_sudoers_entry() {
    log_step "3. Configure Access Level: $ACCESS_LEVEL"

    # Remove any existing configuration
    sed -i "/^$TARGET_USER/d" /etc/sudoers 2>/dev/null || true
    rm -f "/etc/sudoers.d/$TARGET_USER" 2>/dev/null || true

    # Create sudoers.d directory if it doesn't exist
    mkdir -p /etc/sudoers.d

    case $ACCESS_LEVEL in
        dev)
            create_dev_entry
            ;;
        admin)
            create_admin_entry
            ;;
        root)
            create_root_entry
            ;;
        custom)
            create_custom_entry
            ;;
    esac
}

create_dev_entry() {
    log_info "Creating Developer access level"

    SUDOERS_ENTRY="$TARGET_USER ALL=(ALL) NOPASSWD: "
    SUDOERS_ENTRY+="/usr/bin/apt, /usr/bin/apt-get, /usr/bin/dpkg, "
    SUDOERS_ENTRY+="/usr/bin/yum, /usr/bin/dnf, /usr/bin/zypper, "
    SUDOERS_ENTRY+="/usr/bin/pacman, /usr/bin/apk, "
    SUDOERS_ENTRY+="/bin/systemctl, /usr/bin/systemctl, "
    SUDOERS_ENTRY+="/usr/bin/journalctl, /usr/bin/tail, /usr/bin/cat, "
    SUDOERS_ENTRY+="/usr/bin/docker, /usr/bin/podman, "
    SUDOERS_ENTRY+="/usr/sbin/service, /sbin/service"

    echo "$SUDOERS_ENTRY" > "/etc/sudoers.d/$TARGET_USER"
    log_success "Developer access configured"
}

create_admin_entry() {
    log_info "Creating System Administrator access level"

    SUDOERS_ENTRY="$TARGET_USER ALL=(ALL) NOPASSWD: "
    SUDOERS_ENTRY+="/usr/bin/apt, /usr/bin/apt-get, /usr/bin/dpkg, "
    SUDOERS_ENTRY+="/usr/bin/yum, /usr/bin/dnf, /usr/bin/zypper, "
    SUDOERS_ENTRY+="/usr/bin/pacman, /usr/bin/apk, "
    SUDOERS_ENTRY+="/bin/systemctl, /usr/bin/systemctl, "
    SUDOERS_ENTRY+="/usr/bin/journalctl, /usr/sbin/logrotate, "
    SUDOERS_ENTRY+="/usr/sbin/useradd, /usr/sbin/userdel, /usr/sbin/usermod, "
    SUDOERS_ENTRY+="/usr/bin/passwd, /usr/sbin/groupadd, /usr/sbin/groupdel, "
    SUDOERS_ENTRY+="/usr/bin/adduser, /usr/bin/deluser, "
    SUDOERS_ENTRY+="/sbin/ip, /sbin/ifconfig, /sbin/route, "
    SUDOERS_ENTRY+="/usr/sbin/iptables, /usr/sbin/iptables-save, "
    SUDOERS_ENTRY+="/usr/sbin/iptables-restore, /usr/sbin/nft, "
    SUDOERS_ENTRY+="/sbin/fdisk, /sbin/parted, /bin/mount, /bin/umount, "
    SUDOERS_ENTRY+="/usr/sbin/lvm, /sbin/mkfs.*, "
    SUDOERS_ENTRY+="/bin/kill, /usr/bin/killall, /usr/bin/nice, "
    SUDOERS_ENTRY+="/usr/bin/renice, /usr/bin/pkill, "
    SUDOERS_ENTRY+="/usr/sbin/visudo, /usr/bin/crontab, "
    SUDOERS_ENTRY+="/usr/sbin/tcpdump, /usr/bin/netstat, /usr/bin/ss, "
    SUDOERS_ENTRY+="/usr/sbin/rsyslogd, /usr/sbin/logrotate"

    echo "$SUDOERS_ENTRY" > "/etc/sudoers.d/$TARGET_USER"
    log_success "System Administrator access configured"
}

create_root_entry() {
    echo -e "${RED}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                         FINAL WARNING                           ║${NC}"
    echo -e "${RED}║  This will grant FULL ROOT ACCESS without password!            ║${NC}"
    echo -e "${RED}║  User $TARGET_USER will be able to do ANYTHING on the system.  ║${NC}"
    echo -e "${RED}║                                                                  ║${NC}"
    echo -e "${RED}║  Type ${YELLOW}I_UNDERSTAND_THE_RISKS${RED} to continue                     ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    read -p "Confirmation: " confirmation
    if [ "$confirmation" != "I_UNDERSTAND_THE_RISKS" ]; then
        log_error "Operation cancelled - incorrect confirmation phrase"
        exit 1
    fi

    log_warning "⚠️  Granting FULL ROOT access to $TARGET_USER"

    SUDOERS_ENTRY="$TARGET_USER ALL=(ALL) NOPASSWD: ALL"

    echo "$SUDOERS_ENTRY" > "/etc/sudoers.d/$TARGET_USER"
    log_success "Full root access configured (VERY DANGEROUS!)"
}

create_custom_entry() {
    log_info "Interactive custom configuration"

    echo ""
    echo -e "${YELLOW}Custom Sudoers Configuration${NC}"
    echo "Enter commands that $TARGET_USER can run without password."
    echo "Format: One command per line, full path required."
    echo "Examples: /usr/bin/apt, /bin/systemctl"
    echo "Enter 'done' when finished."
    echo ""

    COMMANDS=()
    while true; do
        read -p "Command path: " cmd
        if [ "$cmd" = "done" ]; then
            break
        fi

        # Validate command exists
        if [ -x "$cmd" ] || [[ "$cmd" == /* ]] || [[ "$cmd" == /usr/bin/* ]] || [[ "$cmd" == /bin/* ]] || [[ "$cmd" == /sbin/* ]] || [[ "$cmd" == /usr/sbin/* ]]; then
            COMMANDS+=("$cmd")
            echo "Added: $cmd"
        else
            log_warning "Warning: Command '$cmd' may not exist or is not absolute path"
            read -p "Add anyway? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                COMMANDS+=("$cmd")
            fi
        fi
    done

    if [ ${#COMMANDS[@]} -eq 0 ]; then
        log_error "No commands specified"
        exit 1
    fi

    # Build sudoers entry
    SUDOERS_ENTRY="$TARGET_USER ALL=(ALL) NOPASSWD: "
    for i in "${!COMMANDS[@]}"; do
        if [ $i -gt 0 ]; then
            SUDOERS_ENTRY+=", "
        fi
        SUDOERS_ENTRY+="${COMMANDS[$i]}"
    done

    echo "$SUDOERS_ENTRY" > "/etc/sudoers.d/$TARGET_USER"
    log_success "Custom access configured with ${#COMMANDS[@]} commands"
}

# Verify sudoers syntax
verify_sudoers() {
    log_step "4. Verify Configuration"

    log_info "Checking sudoers syntax..."
    if visudo -c; then
        log_success "Sudoers syntax is valid"
    else
        log_error "Sudoers syntax check failed"
        log_info "Restoring from backup..."
        cp "$BACKUP_FILE" /etc/sudoers
        exit 1
    fi

    # Set correct permissions
    chmod 0440 "/etc/sudoers.d/$TARGET_USER" 2>/dev/null || true
    log_success "File permissions set correctly"
}

# Test the configuration
test_configuration() {
    log_step "5. Test Configuration"

    log_info "Testing sudo access for $TARGET_USER..."

    # Check if user is in sudo group
    if groups "$TARGET_USER" | grep -q "\bsudo\b"; then
        log_success "User is in sudo group"
    else
        log_warning "User is not in sudo group (may need to be added)"
    fi

    # Show the configured entry
    echo ""
    log_info "Configured sudoers entry:"
    if [ -f "/etc/sudoers.d/$TARGET_USER" ]; then
        cat "/etc/sudoers.d/$TARGET_USER"
    else
        grep "^$TARGET_USER" /etc/sudoers || true
    fi

    # Test sudo access
    echo ""
    log_info "To test the configuration, run as $TARGET_USER:"
    echo "  sudo -u $TARGET_USER sudo -n whoami"
    echo ""
    log_info "Or login as $TARGET_USER and test:"
    echo "  sudo -n whoami"
    echo "  sudo -n apt update  # For dev/admin levels"
}

# Main execution
main() {
    # First check if running as root
    check_root

    # Then validate parameters
    validate_parameters

    echo ""
    echo -e "${YELLOW}Configuration Summary:${NC}"
    echo "  User: $TARGET_USER"
    echo "  Access Level: $ACCESS_LEVEL"
    echo "  Backup: $BACKUP_FILE"
    echo ""

    if [ "$ACCESS_LEVEL" = "root" ]; then
        echo -e "${RED}⚠️  WARNING: FULL ROOT ACCESS WILL BE GRANTED${NC}"
    fi

    read -p "Continue with configuration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_error "Operation cancelled by user"
        exit 1
    fi

    backup_sudoers
    check_existing_entry
    create_sudoers_entry
    verify_sudoers
    test_configuration

    log_step "6. Final Summary"
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         Passwordless Sudo Configuration Complete               ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║ Summary:                                                         ║${NC}"
    echo -e "${CYAN}║                                                                  ║${NC}"
    echo -e "${CYAN}║  • Configured User: $TARGET_USER"
    echo -e "${CYAN}║  • Access Level: $ACCESS_LEVEL"
    echo -e "${CYAN}║  • Backup Created: $BACKUP_FILE"
    echo -e "${CYAN}║  • Config File: /etc/sudoers.d/$TARGET_USER"
    echo -e "${CYAN}║                                                                  ║${NC}"
    echo -e "${CYAN}║ Next Steps:                                                      ║${NC}"
    echo -e "${CYAN}║  • User $TARGET_USER should logout and login again             ║${NC}"
    echo -e "${CYAN}║  • Test: ${YELLOW}sudo -u $TARGET_USER sudo -n whoami${CYAN}              ║${NC}"
    echo -e "${CYAN}║  • Review: ${YELLOW}cat /etc/sudoers.d/$TARGET_USER${CYAN}                  ║${NC}"
    echo -e "${CYAN}║  • Backup: ${YELLOW}cp $BACKUP_FILE ~/${CYAN}                             ║${NC}"
    echo -e "${CYAN}║                                                                  ║${NC}"
    echo -e "${CYAN}║ ${RED}⚠️  Security Reminder:${CYAN}                                         ║${NC}"
    echo -e "${CYAN}║  • Monitor sudo usage: ${YELLOW}grep sudo /var/log/auth.log${CYAN}         ║${NC}"
    echo -e "${CYAN}║  • Consider time-based restrictions for sensitive access        ║${NC}"
    echo -e "${CYAN}║                                                                  ║${NC}"

    if [ "$ACCESS_LEVEL" = "root" ]; then
        echo -e "${CYAN}║ ${RED}⚠️  EXTREME RISK: User has FULL ROOT ACCESS!${CYAN}               ║${NC}"
        echo -e "${CYAN}║ ${RED}    Monitor system closely and restrict ASAP!${CYAN}             ║${NC}"
    fi

    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Show success message
    if [ "$ACCESS_LEVEL" = "root" ]; then
        echo -e "${RED}⚠️  SECURITY ALERT: User $TARGET_USER now has FULL ROOT ACCESS!${NC}"
        echo -e "${RED}   This is extremely dangerous. Monitor system activity closely!${NC}"
    else
        echo -e "${GREEN}✅ Configuration completed successfully!${NC}"
    fi
}

# Run main function
main