#!/bin/bash

# Open Ports & Associated Processes Table Script
# Fully fixed version - no AWK syntax errors on Linux, works on macOS
# Colorful table output with robust cross-platform parsing

# Define color constants
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    else
        echo -e "${RED}Error: Unsupported operating system (only macOS/Linux are supported)${NC}"
        exit 1
    fi
}

# Check required commands
check_commands() {
    local required_commands=("awk" "sed" "grep")

    if [ "$OS" = "macos" ]; then
        required_commands+=("lsof")
    else
        required_commands+=("netstat" "ss" "ps")
    fi

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${RED}Error: Required command '$cmd' not found${NC}"
            exit 1
        fi
    done
}

# Fixed: Get open ports and processes (macOS) - robust parsing
get_ports_macos() {
    # Use lsof with explicit options for macOS compatibility
    # -P: disable port name resolution
    # -n: disable host name resolution
    # -i: select Internet files
    # -F: produce machine-readable output (more reliable parsing)
    lsof -P -n -iTCP -iUDP -F npcL 2>/dev/null | awk '
        BEGIN {
            OFS="|"
            port=""
            proto=""
            pid=""
            pname=""
            state=""
        }
        # Process lsof output fields
        /^p/ { pid = substr($0, 2) }          # Process ID
        /^c/ { pname = substr($0, 2) }        # Command/Process name
        /^n/ {                                # Network address
            split(substr($0, 2), addr, /:/);
            if (length(addr) >= 2) {
                # Extract port (last element after colon)
                port = addr[length(addr)];
                # Determine protocol
                if (substr($0, 2) ~ /TCP/) {
                    proto = "TCP";
                } else if (substr($0, 2) ~ /UDP/) {
                    proto = "UDP";
                }
            }
        }
        /^L/ { state = "LISTEN" }             # LISTEN state for TCP
        # Print record when we have complete information
        /^$/ {
            if (port != "" && proto != "" && pid != "") {
                if (proto == "UDP" && state == "") state = "UDP";
                print port, proto, pid, pname, state;
            }
            # Reset variables for next record
            port=""; proto=""; pid=""; pname=""; state=""
        }
    ' | sort -n | uniq | grep -v '^$'
}

# FIXED: Get open ports and processes (Linux) - removed AWK syntax error
get_ports_linux() {
    # First, get TCP ports (no syntax errors)
    tcp_ports=$(netstat -tulpn 2>/dev/null | awk '
        BEGIN { OFS="|" }
        /LISTEN/ {
            # Extract port number
            split($4, addr, ":");
            port = addr[length(addr)];

            # Extract pid and process name
            split($7, pid_proc, "/");
            pid = pid_proc[1];
            pname = pid_proc[2];

            # Skip if port or pid is empty
            if (port == "" || pid == "-") next;

            # Print formatted output: port|protocol|pid|process|state
            print port, "TCP", pid, pname, "LISTEN";
        }
    ')

    # Second, get UDP ports (FIXED: no inline shell execution in AWK)
    udp_ports=$(ss -ulpn 2>/dev/null | awk '
        BEGIN { OFS="|" }
        /UDP/ {
            # Extract port number
            split($4, addr, ":");
            port = addr[length(addr)];

            # Extract pid (no shell execution here - avoid syntax error)
            pid = "-";
            pname = "unknown";
            if ($7 ~ /pid:/) {
                split($7, pid_part, /pid=|,/);
                pid = pid_part[2];
            }

            # Skip if port is empty
            if (port == "") next;

            # Print formatted output: port|protocol|pid|process|state
            print port, "UDP", pid, pname, "UDP";
        }
    ')

    # Post-process UDP ports to get process names (fix for AWK syntax error)
    # Use shell loop instead of inline AWK execution to get process names
    processed_udp_ports=""
    while IFS='|' read -r port proto pid pname state; do
        if [ "$pid" != "-" ] && [ "$pid" != "" ] && [[ "$pid" =~ ^[0-9]+$ ]]; then
            # Get process name using ps (shell command, not AWK)
            new_pname=$(ps -p "$pid" -o comm= 2>/dev/null)
            if [ -n "$new_pname" ]; then
                pname="$new_pname"
            fi
        fi
        processed_udp_ports+="$port|$proto|$pid|$pname|$state"$'\n'
    done <<< "$udp_ports"

    # Combine TCP and processed UDP ports, sort and deduplicate
    (
        echo "$tcp_ports"
        echo "$processed_udp_ports"
    ) | sort -n | uniq | grep -v '^$'
}

# Display ports in colorful table format
display_table() {
    echo -e "${BLUE}+--------+----------+-------+------------------------+------------+${NC}"
    printf "${BLUE}| %-6s | %-8s | %-5s | %-22s | %-10s |${NC}\n" "Port" "Protocol" "PID" "Process Name" "State"
    echo -e "${BLUE}+--------+----------+-------+------------------------+------------+${NC}"

    local port_data=$1
    local row_count=0

    # Read and display each port entry
    while IFS='|' read -r port proto pid pname state; do
        # Skip empty lines
        if [ -z "$port" ]; then
            continue
        fi

        row_count=$((row_count + 1))

        # Truncate long process names
        if [ ${#pname} -gt 22 ]; then
            pname="${pname:0:19}..."
        fi

        # Alternate row colors for better readability
        if [ $((row_count % 2)) -eq 1 ]; then
            printf "${GREEN}| %-6s | %-8s | %-5s | %-22s | %-10s |${NC}\n" "$port" "$proto" "$pid" "$pname" "$state"
        else
            printf "${CYAN}| %-6s | %-8s | %-5s | %-22s | %-10s |${NC}\n" "$port" "$proto" "$pid" "$pname" "$state"
        fi
        echo -e "${BLUE}+--------+----------+-------+------------------------+------------+${NC}"
    done <<< "$port_data"

    # Handle empty result
    if [ $row_count -eq 0 ]; then
        printf "${YELLOW}| %-6s | %-8s | %-5s | %-22s | %-10s |${NC}\n" "None" "None" "None" "No open ports found" "None"
        echo -e "${BLUE}+--------+----------+-------+------------------------+------------+${NC}"
    fi
}

# Main program
main() {
    # Initial setup
    detect_os
    check_commands

    echo -e "${PURPLE}==================== Open Ports & Process Information ====================${NC}\n"

    # Get port data based on OS
    if [ "$OS" = "macos" ]; then
        port_data=$(get_ports_macos)
    else
        port_data=$(get_ports_linux)
    fi

    # Display results in table
    display_table "$port_data"

    echo -e "\n${YELLOW}Notes:${NC}"
    echo -e "  - Running with sudo is required for full process visibility on macOS/Linux"
    echo -e "  - Alternating colors (green/cyan) help distinguish between different port entries"
    echo -e "  - Process names longer than 22 chars are truncated with '...'"
}

# Execute main program
main