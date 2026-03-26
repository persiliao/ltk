#!/usr/bin/env zsh

# Script: setup_ssh_key_auth.zsh
# Function: Configure SSH public key authentication for current user
# Description: Automatically creates necessary directories and files, ensures configuration success

__persiliao_set_strict_mode() {
    # Enable strict mode
    set -euo pipefail
}

__persiliao_show_header() {
    # Display script header
    echo "=== SSH Public Key Configuration Script ==="
    echo "User: $(whoami)"
    echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
}

__persiliao_get_public_key_path() {
    # Get public key file path
    local pub_key_path="$1"

    if [[ -z "$pub_key_path" ]] || [[ "$pub_key_path" == "--help" ]] || [[ "$pub_key_path" == "-h" ]]; then
        echo "Usage: $0 [public_key_file_path]"
        echo ""
        echo "Examples:"
        echo "  $0 /path/to/login.pub"
        echo "  $0                         # Use login.pub in current directory"
        echo ""
        echo "Note: This script only configures SSH public key for current user $(whoami)"
        exit 1
    fi

    # Resolve path
    if [[ ! -f "$pub_key_path" ]]; then
        echo "Error: Public key file does not exist: $pub_key_path"
        exit 1
    fi

    echo "$(realpath "$pub_key_path" 2>/dev/null || echo "$pub_key_path")"
}

__persiliao_validate_public_key() {
    # Validate public key format
    local pub_key_path="$1"
    local pub_key_content=""

    echo "Validating public key file: $pub_key_path"

    # Read file content
    pub_key_content=$(cat "$pub_key_path" 2>/dev/null | tr -d '\r\n' | sed 's/[[:space:]]*$//')

    if [[ -z "$pub_key_content" ]]; then
        echo "Error: Public key file is empty"
        exit 1
    fi

    # Validate SSH public key format
    if ! echo "$pub_key_content" | grep -q -E "^(ssh-(rsa|dss|ed25519)|ecdsa-sha2-nistp(256|384|521)|ssh-ed25519-cert-v01@openssh\.com)"; then
        echo "Error: Invalid SSH public key format"
        echo "Supported formats: ssh-rsa, ssh-dss, ssh-ed25519, ecdsa-sha2-nistp256/384/521"
        echo ""
        echo "First 100 characters of file content:"
        echo "$pub_key_content" | cut -c 1-100
        exit 1
    fi

    echo "✓ Public key format validated"
    echo "  Key type: $(echo "$pub_key_content" | awk '{print $1}')"
    echo "  Key length: $(echo -n "$pub_key_content" | wc -c | awk '{print $1}') characters"
    echo ""

    echo "$pub_key_content"
}

__persiliao_create_ssh_directory() {
    # Create .ssh directory and set permissions
    local ssh_dir="$HOME/.ssh"

    echo "Configuring SSH directory: $ssh_dir"

    if [[ ! -d "$ssh_dir" ]]; then
        echo "Creating .ssh directory..."
        mkdir -p "$ssh_dir"
        echo "✓ Directory created"
    else
        echo "✓ Directory exists"
    fi

    # Ensure correct directory permissions
    local current_perm=""
    if [[ $(uname) == "Darwin" ]]; then
        current_perm=$(stat -f "%A" "$ssh_dir" 2>/dev/null || echo "755")
    else
        current_perm=$(stat -c "%a" "$ssh_dir" 2>/dev/null || echo "755")
    fi

    if [[ "$current_perm" != "700" ]] && [[ "$current_perm" != "750" ]] && [[ "$current_perm" != "755" ]]; then
        echo "Updating directory permissions: 0700"
        chmod 700 "$ssh_dir"
    else
        echo "✓ Directory permissions correct: $current_perm"
    fi

    echo ""
    echo "$ssh_dir"
}

__persiliao_create_authorized_keys_file() {
    # Create authorized_keys file
    local auth_keys_file="$HOME/.ssh/authorized_keys"

    echo "Configuring authorized_keys file: $auth_keys_file"

    if [[ ! -f "$auth_keys_file" ]]; then
        echo "Creating authorized_keys file..."
        touch "$auth_keys_file"
        echo "# SSH Authorized Keys for $(whoami)" > "$auth_keys_file"
        echo "# Created: $(date '+%Y-%m-%d %H:%M:%S')" >> "$auth_keys_file"
        echo "" >> "$auth_keys_file"
        echo "✓ File created"
    else
        echo "✓ File exists"
    fi

    # Ensure correct file permissions
    local current_perm=""
    if [[ $(uname) == "Darwin" ]]; then
        current_perm=$(stat -f "%A" "$auth_keys_file" 2>/dev/null || echo "644")
    else
        current_perm=$(stat -c "%a" "$auth_keys_file" 2>/dev/null || echo "644")
    fi

    if [[ "$current_perm" != "600" ]] && [[ "$current_perm" != "644" ]]; then
        echo "Updating file permissions: 0600"
        chmod 600 "$auth_keys_file"
    else
        echo "✓ File permissions correct: $current_perm"
    fi

    echo ""
    echo "$auth_keys_file"
}

__persiliao_backup_existing_keys() {
    # Backup existing authorized_keys file
    local auth_keys_file="$1"

    if [[ ! -f "$auth_keys_file" ]]; then
        return 0
    fi

    # Check if file has content (excluding comments and empty lines)
    local key_count=$(grep -v "^#" "$auth_keys_file" | grep -v "^$" | wc -l | awk '{print $1}')

    if [[ $key_count -eq 0 ]]; then
        echo "ℹ️  File is empty, no backup needed"
        return 0
    fi

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${auth_keys_file}.backup.${timestamp}"

    echo "Backing up existing configuration..."
    cp "$auth_keys_file" "$backup_file"
    chmod 600 "$backup_file"

    echo "✓ Backup completed: $backup_file"
    echo "  Backup contains $key_count valid keys"
    echo ""

    # Clean up old backups
    __persiliao_cleanup_old_backups "$auth_keys_file"
}

__persiliao_cleanup_old_backups() {
    # Clean up old backup files, keep latest 5
    local auth_keys_file="$1"
    local backup_dir=$(dirname "$auth_keys_file")
    local base_name=$(basename "$auth_keys_file")

    local backup_files=($(find "$backup_dir" -name "${base_name}.backup.*" -type f 2>/dev/null | sort -r))
    local backup_count=${#backup_files[@]}

    if [[ $backup_count -gt 5 ]]; then
        echo "Cleaning up old backup files..."
        for ((i=5; i<backup_count; i++)); do
            echo "  Deleting: ${backup_files[$i]}"
            rm -f "${backup_files[$i]}"
        done
        echo "✓ Keeping latest 5 backups"
        echo ""
    fi
}

__persiliao_check_key_exists() {
    # Check if key already exists
    local auth_keys_file="$1"
    local new_key="$2"

    if [[ ! -f "$auth_keys_file" ]]; then
        return 1
    fi

    echo "Checking if key already exists..."

    # Use multiple methods to check
    local temp_file=$(mktemp)
    echo "$new_key" > "$temp_file"

    # Method 1: Check fingerprint using ssh-keygen
    if command -v ssh-keygen >/dev/null 2>&1; then
        local new_fingerprint=$(ssh-keygen -lf "$temp_file" 2>/dev/null | awk 'NR==1{print $2}')

        if [[ -n "$new_fingerprint" ]]; then
            while IFS= read -r line; do
                if [[ -n "$line" ]] && [[ ! "$line" =~ ^# ]]; then
                    local temp_line_file=$(mktemp)
                    echo "$line" > "$temp_line_file"
                    local line_fingerprint=$(ssh-keygen -lf "$temp_line_file" 2>/dev/null | awk 'NR==1{print $2}')
                    rm -f "$temp_line_file"

                    if [[ "$line_fingerprint" == "$new_fingerprint" ]]; then
                        rm -f "$temp_file"
                        echo "✓ Key with same fingerprint already exists"
                        return 0
                    fi
                fi
            done < "$auth_keys_file"
        fi
    fi

    # Method 2: Direct key content comparison
    local clean_new_key=$(echo "$new_key" | tr -d ' ' | tr -d '\n' | tr -d '\r')

    while IFS= read -r line; do
        if [[ -n "$line" ]] && [[ ! "$line" =~ ^# ]]; then
            local clean_line=$(echo "$line" | tr -d ' ' | tr -d '\n' | tr -d '\r')
            if [[ "$clean_line" == "$clean_new_key" ]]; then
                rm -f "$temp_file"
                echo "✓ Exactly identical key already exists"
                return 0
            fi
        fi
    done < "$auth_keys_file"

    rm -f "$temp_file"
    echo "✓ Key not found, can be added"
    return 1
}

__persiliao_add_public_key() {
    # Add public key to authorized_keys
    local auth_keys_file="$1"
    local pub_key_content="$2"

    echo "Adding public key to authorized_keys..."

    echo "$pub_key_content" >> "$auth_keys_file"

    echo "✓ Public key added"
    echo ""
}

__persiliao_verify_configuration() {
    # Verify configuration
    local auth_keys_file="$1"
    local pub_key_content="$2"

    echo "Verifying configuration..."

    # Check if file exists
    if [[ ! -f "$auth_keys_file" ]]; then
        echo "Error: authorized_keys file does not exist"
        return 1
    fi

    # Check permissions
    local file_perm=""
    if [[ $(uname) == "Darwin" ]]; then
        file_perm=$(stat -f "%A" "$auth_keys_file" 2>/dev/null || echo "")
    else
        file_perm=$(stat -c "%a" "$auth_keys_file" 2>/dev/null || echo "")
    fi

    if [[ "$file_perm" != "600" ]] && [[ "$file_perm" != "644" ]]; then
        echo "Warning: File permissions may be incorrect: $file_perm (should be 600 or 644)"
    else
        echo "✓ File permissions correct: $file_perm"
    fi

    # Check if key was successfully added
    if grep -q -F "$pub_key_content" "$auth_keys_file"; then
        echo "✓ Key successfully added to file"
    else
        echo "Error: Key not found in file"
        return 1
    fi

    # Count keys
    local key_count=$(grep -v "^#" "$auth_keys_file" | grep -v "^$" | grep -c "ssh-" || echo "0")
    echo "✓ File contains $key_count SSH keys"
    echo ""

    return 0
}

__persiliao_generate_test_commands() {
    # Generate test commands
    local current_user=$(whoami)
    local auth_keys_file="$HOME/.ssh/authorized_keys"

    echo "=== Configuration Complete ==="
    echo ""
    echo "✅ SSH public key configuration successful!"
    echo ""

    # Display file information
    echo "Configuration information:"
    echo "  └─ User: $current_user"
    echo "  └─ Config file: $auth_keys_file"

    if [[ $(uname) == "Darwin" ]]; then
        echo "  └─ File size: $(stat -f%z "$auth_keys_file" 2>/dev/null || echo "N/A") bytes"
    else
        echo "  └─ File size: $(stat -c%s "$auth_keys_file" 2>/dev/null || echo "N/A") bytes"
    fi

    echo ""
    echo "Test connection commands:"
    echo ""

    # Generate test commands
    if command -v hostname >/dev/null 2>&1; then
        local hostname_str=$(hostname)
        echo "1. Local test:"
        echo "   ssh ${current_user}@${hostname_str}"
        echo ""
    fi

    echo "2. General test command:"
    echo "   ssh ${current_user}@localhost"
    echo ""

    # Get IP addresses
    echo "3. Network connection test:"
    if [[ $(uname) == "Darwin" ]]; then
        # macOS
        local ip_addresses=$(ifconfig 2>/dev/null | grep -E "inet (192\.168|10\.|172\.)" | awk '{print $2}' | grep -v "127.0.0.1" | head -3)
    else
        # Linux
        local ip_addresses=$(ip -4 addr show 2>/dev/null | grep -E "inet (192\.168|10\.|172\.)" | awk '{print $2}' | cut -d/ -f1 | head -3)
    fi

    if [[ -n "$ip_addresses" ]]; then
        for ip in ${=ip_addresses}; do
            echo "   ssh ${current_user}@${ip}"
        done
    else
        echo "   ssh ${current_user}@<server_ip_address>"
    fi

    echo ""
    echo "4. Quick test:"
    echo "   ssh -o ConnectTimeout=5 ${current_user}@localhost 'echo ✅ SSH connection successful'"
    echo ""

    echo "5. Verification commands:"
    echo "   ls -la ~/.ssh/authorized_keys"
    echo "   tail -5 ~/.ssh/authorized_keys"
    echo ""

    echo "Note: If connection fails, ensure SSH server has public key authentication enabled"
    echo "      Check: grep 'PubkeyAuthentication yes' /etc/ssh/sshd_config"
    echo ""
    echo "Backup files: ${auth_keys_file}.backup.*"
}

__persiliao_check_ssh_service_status() {
    # Check SSH service status (display only, no modifications)
    echo ""
    echo "SSH service status check:"

    if [[ $(uname) == "Darwin" ]]; then
        # macOS
        local ssh_status=$(sudo launchctl list 2>/dev/null | grep -i ssh || echo "Unknown")
        echo "  macOS SSH service: $ssh_status"
    else
        # Linux
        if command -v systemctl >/dev/null 2>&1; then
            systemctl status sshd --no-pager 2>/dev/null | head -3 | grep -E "(active|inactive)" || \
            systemctl status ssh --no-pager 2>/dev/null | head -3 | grep -E "(active|inactive)" || \
            echo "  SSH service status: Unable to determine"
        elif command -v service >/dev/null 2>&1; then
            service sshd status 2>/dev/null | head -3 || \
            service ssh status 2>/dev/null | head -3 || \
            echo "  SSH service status: Unable to determine"
        fi
    fi
    echo ""
}

__persiliao_main() {
    # Main function
    __persiliao_set_strict_mode
    __persiliao_show_header

    local pub_key_path=""
    local pub_key_content=""
    local auth_keys_file="$HOME/.ssh/authorized_keys"

    # Get public key file path
    if [[ $# -eq 1 ]]; then
        pub_key_path="$1"
    fi

    pub_key_path=$(__persiliao_get_public_key_path "$pub_key_path")

    # Validate public key
    pub_key_content=$(__persiliao_validate_public_key "$pub_key_path")

    # Create .ssh directory
    __persiliao_create_ssh_directory > /dev/null

    # Create authorized_keys file
    __persiliao_create_authorized_keys_file > /dev/null

    # Check if key already exists
    if __persiliao_check_key_exists "$auth_keys_file" "$pub_key_content"; then
        echo "ℹ️  This public key already exists in configuration, no need to add again"
        __persiliao_generate_test_commands
        exit 0
    fi

    # Add public key
    __persiliao_add_public_key "$auth_keys_file" "$pub_key_content"

    # Verify configuration
    if ! __persiliao_verify_configuration "$auth_keys_file" "$pub_key_content"; then
        echo "Error: Configuration verification failed"
        exit 1
    fi

    # Generate test commands
    __persiliao_generate_test_commands

    # Check SSH service status
    __persiliao_check_ssh_service_status

    echo "✅ Configuration completed successfully!"
}

# Run main function
__persiliao_main "$@"
