#!/bin/bash

# Cursor Bridge Service Startup Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting Cursor Bridge Service...${NC}"

# Check Node.js version
if ! command -v node &> /dev/null; then
    echo -e "${RED}Error: Node.js is not installed${NC}"
    exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo -e "${RED}Error: Node.js 18.0 or higher is required (found: $(node -v))${NC}"
    exit 1
fi

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}Warning: .env file not found${NC}"
    echo -e "${YELLOW}Creating .env from .env.example...${NC}"
    if [ -f .env.example ]; then
        cp .env.example .env
        echo -e "${YELLOW}Please edit .env and add your CURSOR_API_KEY${NC}"
        exit 1
    else
        echo -e "${RED}Error: .env.example not found${NC}"
        exit 1
    fi
fi

# Check if CURSOR_API_KEY is set
source .env
if [ -z "$CURSOR_API_KEY" ]; then
    echo -e "${RED}Error: CURSOR_API_KEY not set in .env${NC}"
    echo -e "${YELLOW}Please edit .env and add your API key${NC}"
    exit 1
fi

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo -e "${YELLOW}Installing dependencies...${NC}"
    npm install
fi

# Build TypeScript if needed
if [ ! -d "dist" ] || [ "src" -nt "dist" ]; then
    echo -e "${YELLOW}Building TypeScript...${NC}"
    npm run build
fi

# Create data directory for database
DB_DIR="${HOME}/.cursor-bridge"
mkdir -p "$DB_DIR"

echo -e "${GREEN}Bridge service configuration:${NC}"
echo -e "  HTTP Port: ${HTTP_PORT:-8765}"
echo -e "  WS Port: ${WS_PORT:-8766}"
echo -e "  Database: ${DB_PATH:-${DB_DIR}/sessions.db}"
echo ""

# Start the service
echo -e "${GREEN}Starting server...${NC}"
npm start
