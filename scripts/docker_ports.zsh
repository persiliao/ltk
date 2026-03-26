#!/bin/bash

# Docker Port Mapping Information Table Script
# Cross-platform compatible (macOS/Linux) with colorful output

# Define color constants
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}Error: Docker is not running or installed. Please start Docker first.${NC}"
        exit 1
    fi
}

# Get container port mapping information and generate table with image info
show_ports_table() {
    # Table header (blue)
    echo -e "${BLUE}+------------------+---------------------+------------------------------+----------------+----------------+${NC}"
    printf "${BLUE}| %-16s | %-19s | %-28s | %-14s | %-14s |${NC}\n" "Container ID" "Container Name" "Image" "Host Port" "Container Port/Protocol"
    echo -e "${BLUE}+------------------+---------------------+------------------------------+----------------+----------------+${NC}"

    # Get all running container IDs
    container_ids=$(docker ps -q)

    # If no running containers
    if [ -z "$container_ids" ]; then
        printf "${YELLOW}| %-16s | %-19s | %-28s | %-14s | %-14s |${NC}\n" "None" "No running containers" "None" "None" "None"
        echo -e "${BLUE}+------------------+---------------------+------------------------------+----------------+----------------+${NC}"
        return
    fi

    # Iterate through each container
    for cid in $container_ids; do
        # Get basic container information
        container_name=$(docker inspect --format '{{.Name}}' $cid | sed 's/^\///')
        container_image=$(docker inspect --format '{{.Config.Image}}' $cid)
        short_cid=$(echo $cid | cut -c1-12)

        # Truncate long image names to fit table (max 28 chars)
        if [ ${#container_image} -gt 28 ]; then
            container_image="${container_image:0:25}..."
        fi

        # Get port mapping information
        port_mappings=$(docker inspect --format '{{range $p, $conf := .NetworkSettings.Ports}}{{$p}}|{{(index $conf 0).HostPort}} {{end}}' $cid)

        # If no port mappings
        if [ -z "$port_mappings" ]; then
            printf "${GREEN}| %-16s | %-19s | %-28s | %-14s | %-14s |${NC}\n" "$short_cid" "$container_name" "$container_image" "None" "None"
            echo -e "${BLUE}+------------------+---------------------+------------------------------+----------------+----------------+${NC}"
            continue
        fi

        # Handle multiple port mappings
        first_line=true
        while IFS='|' read -r container_port host_port; do
            # Clean up whitespace
            host_port=$(echo "$host_port" | xargs)
            container_port=$(echo "$container_port" | xargs)

            if $first_line; then
                # First line shows full container info (green)
                printf "${GREEN}| %-16s | %-19s | %-28s | %-14s | %-14s |${NC}\n" "$short_cid" "$container_name" "$container_image" "$host_port" "$container_port"
                first_line=false
            else
                # Subsequent lines show only port info (cyan)
                printf "${CYAN}| %-16s | %-19s | %-28s | %-14s | %-14s |${NC}\n" "" "" "" "$host_port" "$container_port"
            fi
        done <<< "$(echo -e "$port_mappings")"

        echo -e "${BLUE}+------------------+---------------------+------------------------------+----------------+----------------+${NC}"
    done
}

# Main program
main() {
    check_docker
    echo -e "${PURPLE}==================== Docker Port Mapping Information ====================${NC}\n"
    show_ports_table
    echo -e "\n${YELLOW}Note:${NC} Empty Container ID/Name/Image indicates multiple port mappings for the same container"
}

# Execute main program
main