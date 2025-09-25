#!/bin/bash

# Serve CHEXX web build locally
echo "🌐 Starting CHEXX Web Server..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[SERVER]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if build exists
if [[ ! -d "build/web" ]] || [[ ! -f "build/web/index.html" ]]; then
    print_error "Web build not found. Building now..."
    ./build_web.sh

    if [[ $? -ne 0 ]]; then
        print_error "Build failed. Cannot start server."
        exit 1
    fi
fi

print_success "Web build found ✅"

# Change to build directory
cd build/web

print_status "Starting Python HTTP server on port 9090..."
print_status "Server will be available at: http://localhost:9090"
print_status "Press Ctrl+C to stop the server"
echo ""

# Start server and open browser
if command -v python3 &> /dev/null; then
    # Start Python server in background
    python3 -m http.server 9090 --bind localhost &
    SERVER_PID=$!

    # Wait a moment for server to start
    sleep 2

    # Open Firefox if available
    if command -v firefox &> /dev/null; then
        print_success "Opening Firefox..."
        firefox http://localhost:9090 > /dev/null 2>&1 &
    else
        print_status "Firefox not found. Open http://localhost:9090 in your browser"
    fi

    # Wait for server process
    wait $SERVER_PID
else
    print_error "Python3 not found. Cannot start HTTP server."
    print_status "Please install Python3 or use: ./start.sh"
    exit 1
fi