#!/bin/bash

# Cursor Emacs Bridge - Startup Script (Python with uv)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting Cursor Emacs Bridge Service..."

# Check if uv is installed
if ! command -v uv &> /dev/null; then
    echo "Error: uv is not installed"
    echo "Install uv with:"
    echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
    echo ""
    echo "Or visit: https://github.com/astral-sh/uv"
    exit 1
fi

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is not installed"
    echo "Please install Python 3.8 or later"
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment with uv..."
    uv venv
fi

# Activate virtual environment
echo "Activating virtual environment..."
source .venv/bin/activate

# Install/sync dependencies
if [ -f "requirements.txt" ]; then
    echo "Installing dependencies from requirements.txt with uv..."
    uv pip install -r requirements.txt
elif [ -f "pyproject.toml" ]; then
    echo "Installing dependencies with uv..."
    uv pip install -e .
else
    echo "Error: No requirements.txt or pyproject.toml found"
    exit 1
fi

# Check for .env file
if [ ! -f ".env" ]; then
    echo "Warning: .env file not found"
    if [ -f ".env.example" ]; then
        echo "Creating .env from .env.example..."
        cp .env.example .env
        echo ""
        echo "Please edit .env and add your CURSOR_API_KEY"
        echo "Then run this script again"
        exit 1
    else
        echo "No .env.example found. Please create a .env file with your configuration."
        exit 1
    fi
fi

# Auto-detect main Python file
MAIN_FILE="server.py"
if [ ! -f "$MAIN_FILE" ]; then
    echo "Error: $MAIN_FILE not found"
    exit 1
fi

# Start the server
echo "Starting server..."
python3 "$MAIN_FILE"
