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

# Function to check and kill process using port 8888
check_and_kill_port_8888() {
    local port=8888
    print_status "Checking if port $port is in use..."

    # Check if port is in use using lsof
    if command -v lsof &> /dev/null; then
        local pid=$(lsof -ti :$port 2>/dev/null | head -1)

        if [[ -n "$pid" ]]; then
            # Get process name and command for the PID
            local process_name=$(ps -p $pid -o comm= 2>/dev/null || echo "unknown")
            local process_cmd=$(ps -p $pid -o cmd= 2>/dev/null || echo "unknown")

            print_status "Port $port is in use by process: $process_name (PID: $pid)"
            print_status "Process command: $process_cmd"

            # Kill only the specific process, not related browser processes
            if [[ "$process_name" != "firefox" ]] && [[ "$process_name" != "chrome" ]] && [[ "$process_name" != "chromium" ]]; then
                print_status "Killing process $pid ($process_name)..."
                if kill $pid 2>/dev/null; then
                    sleep 2
                    # Verify the process is dead
                    if ! kill -0 $pid 2>/dev/null; then
                        print_success "Successfully killed process using port $port"
                    else
                        print_status "Process still running, trying force kill..."
                        kill -9 $pid 2>/dev/null
                        sleep 1
                    fi
                else
                    print_error "Failed to kill process $pid"
                fi
            else
                print_status "Process appears to be a browser. Skipping kill to avoid disrupting user's browsing."
                print_status "You may need to manually close the tab or process using port $port"
            fi
        else
            print_success "Port $port is available"
        fi
    else
        # Fallback using netstat if lsof is not available
        print_status "lsof not found, using netstat as fallback..."
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            print_status "Port $port appears to be in use (netstat check)"
            print_status "Please manually check: netstat -tuln | grep :$port"
        else
            print_success "Port $port appears available (netstat check)"
        fi
    fi
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

print_status "Starting Python HTTP server on port 8888..."
print_status "Server will be available at: http://localhost:8888"
print_status "Press Ctrl+C to stop the server"
echo ""

# Start server and open browser
if command -v python3 &> /dev/null; then
    # Check and kill any process using port 8888
    check_and_kill_port_8888

    # Start Python server in background
    python3 -m http.server 8888 --bind localhost &
    SERVER_PID=$!

    # Wait a moment for server to start
    sleep 2

    # Open Firefox if available
    if command -v firefox &> /dev/null; then
        print_success "Opening Firefox..."
        firefox http://localhost:8888 > /dev/null 2>&1 &
    else
        print_status "Firefox not found. Open http://localhost:8888 in your browser"
    fi

    # Wait for server process
    wait $SERVER_PID
else
    print_error "Python3 not found. Cannot start HTTP server."
    print_status "Please install Python3 or use: ./start.sh"
    exit 1
fi