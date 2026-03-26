#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   PBX Setup Wizard                      ${NC}"
echo -e "${GREEN}=========================================${NC}"

# 1. Prerequisites
echo -e "\n[1/8] Checking Prerequisites..."

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}"
   exit 1
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: Git is not installed${NC}"
    exit 1
fi

if [[ ! -f "docker-compose.yml" ]]; then
    echo -e "${RED}Error: Script must be run from the pbx/ project folder${NC}"
    exit 1
fi

if [[ -f ".env" ]]; then
    echo -e "${YELLOW}Warning: .env already exists. Setup was already performed.${NC}"
    echo -e "To reset: delete .env and run again."
    exit 1
fi

# 1b. Python Dependencies
echo -e "\n[1.1/4] Checking Python Dependencies..."
if ! command -v pip3 &> /dev/null; then
    echo -e "pip3 not found. Installing..."
    apt update && apt install python3-pip -y
fi

echo -e "Installing bcrypt..."
if pip3 install bcrypt --break-system-packages; then
    echo -e "${GREEN}Python dependencies installed successfully.${NC}"
else
    echo -e "${RED}Error: Failed to install Python dependencies.${NC}"
    exit 1
fi

# 2. Loki Logging Plugin
echo -e "\n[2/4] Checking Loki Logging Plugin..."
if docker plugin ls | grep -q "loki"; then
    echo -e "${GREEN}Loki Docker driver is already installed.${NC}"
else
    echo -e "Installing Loki Docker driver..."
    if docker plugin install grafana/loki-docker-driver:latest --alias loki --grant-all-permissions; then
        echo -e "${GREEN}Loki Docker driver installed successfully.${NC}"
    else
        echo -e "${RED}Error: Failed to install Loki Docker driver.${NC}"
        exit 1
    fi
fi

# 3. Start Setup Server
echo -e "\n[3/4] Starting Setup Wizard..."

PRIVATE_IP=$(hostname -I | awk '{print $1}')
PORT=5015

echo -e "${YELLOW}-----------------------------------------${NC}"
echo -e "${GREEN}PBX Setup available at: ${YELLOW}http://$PRIVATE_IP:$PORT${NC}"
echo -e "${YELLOW}-----------------------------------------${NC}"
echo -e "Waiting for setup completion..."

# Start the Python setup server
# It will self-terminate after successful setup
python3 scripts/setup_server.py

# 4. Finalizing
if [[ -f ".env" ]]; then
    echo -e "\n${GREEN}=========================================${NC}"
    echo -e "${GREEN}   Setup Complete!                       ${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo -e "You can now access your PBX."
else
    echo -e "\n${RED}Setup was cancelled or failed.${NC}"
    exit 1
fi

