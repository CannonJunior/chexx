#!/bin/bash

# CHEXX - Hexagonal Turn-Based Strategy Game
# Launch script for local development

set -e

echo "🎯 CHEXX Game Launcher"
echo "======================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
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

            print_warning "Port $port is in use by process: $process_name (PID: $pid)"
            print_status "Process command: $process_cmd"

            # Kill only the specific process, not related browser processes
            if [[ "$process_name" != "firefox" ]] && [[ "$process_name" != "chrome" ]] && [[ "$process_name" != "chromium" ]] && [[ "$process_name" != "google-chrome" ]]; then
                print_status "Killing process $pid ($process_name)..."
                if kill $pid 2>/dev/null; then
                    sleep 2
                    # Verify the process is dead
                    if ! kill -0 $pid 2>/dev/null; then
                        print_success "Successfully killed process using port $port"
                    else
                        print_warning "Process still running, trying force kill..."
                        kill -9 $pid 2>/dev/null
                        sleep 1
                    fi
                else
                    print_error "Failed to kill process $pid"
                fi
            else
                print_warning "Process appears to be a browser. Skipping kill to avoid disrupting user's browsing."
                print_status "You may need to manually close the tab or process using port $port"
            fi
        else
            print_success "Port $port is available"
        fi
    else
        # Fallback using netstat if lsof is not available
        print_warning "lsof not found, using netstat as fallback..."
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            print_warning "Port $port appears to be in use (netstat check)"
            print_status "Please manually check: netstat -tuln | grep :$port"
        else
            print_success "Port $port appears available (netstat check)"
        fi
    fi
}

# Check if Flutter is installed or available in common locations
FLUTTER_PATH=""

if command -v flutter &> /dev/null; then
    print_success "Flutter is already available in PATH"
    FLUTTER_PATH=$(which flutter)
elif [[ -f "$HOME/development/flutter/bin/flutter" ]]; then
    print_status "Found Flutter in ~/development/flutter, adding to PATH..."
    export PATH="$PATH:$HOME/development/flutter/bin"
    FLUTTER_PATH="$HOME/development/flutter/bin/flutter"
elif [[ -f "/opt/flutter/bin/flutter" ]]; then
    print_status "Found Flutter in /opt/flutter, adding to PATH..."
    export PATH="$PATH:/opt/flutter/bin"
    FLUTTER_PATH="/opt/flutter/bin/flutter"
else
    print_warning "Flutter not found, installing..."

    # Download and install Flutter
    cd /tmp
    if [[ ! -f flutter_linux_3.24.3-stable.tar.xz ]]; then
        print_status "Downloading Flutter SDK..."
        wget -q --show-progress https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.3-stable.tar.xz
    fi

    if [[ -d flutter ]]; then
        rm -rf flutter
    fi

    print_status "Extracting Flutter..."
    tar xf flutter_linux_3.24.3-stable.tar.xz

    # Install to user directory (no sudo required)
    mkdir -p ~/development
    if [[ -d ~/development/flutter ]]; then
        rm -rf ~/development/flutter
    fi
    mv flutter ~/development/

    FLUTTER_PATH="$HOME/development/flutter/bin/flutter"
    cd - > /dev/null
    print_success "Flutter installed to ~/development/flutter"
fi

# Ensure Flutter is in PATH for this session
export PATH="$PATH:$HOME/development/flutter/bin:/opt/flutter/bin"

# Add to shell profiles for future sessions
FLUTTER_PATH_EXPORT='export PATH="$PATH:$HOME/development/flutter/bin:/opt/flutter/bin"'

for profile in ~/.bashrc ~/.zshrc ~/.profile; do
    if [[ -f "$profile" ]] && ! grep -q "flutter/bin" "$profile"; then
        echo "$FLUTTER_PATH_EXPORT" >> "$profile"
        print_status "Added Flutter to $profile"
    fi
done

# Verify Flutter is now available
if command -v flutter &> /dev/null; then
    print_success "✅ Flutter is now available in PATH: $(which flutter)"
else
    print_error "❌ Failed to add Flutter to PATH"
    exit 1
fi

# Verify Flutter installation
print_status "Verifying Flutter installation..."
flutter --version

# Return to project directory
cd "$(dirname "$0")"
print_status "Working directory: $(pwd)"

# Check for required files
if [[ ! -f "pubspec.yaml" ]]; then
    print_error "pubspec.yaml not found. Please run this script from the CHEXX project directory."
    exit 1
fi

# Install dependencies
print_status "Installing Flutter dependencies..."
if flutter pub get; then
    print_success "Dependencies installed successfully"
else
    print_error "Failed to install dependencies"
    exit 1
fi

# Check Flutter doctor (but don't fail on warnings)
print_status "Running Flutter doctor..."
flutter doctor || print_warning "Flutter doctor found some issues, but continuing anyway..."

# Choose platform
echo ""
echo "🚀 Choose launch platform:"
echo "1) Web (Chrome) - Flutter dev server"
echo "2) Web (Chrome) - Python HTTP server (if option 1 fails)"
echo "3) Desktop (Linux)"
echo "4) Android (if device/emulator connected)"
echo "5) Check available devices"

read -p "Enter choice (1-5) [default: 1]: " choice
choice=${choice:-1}

case $choice in
    1)
        print_status "Launching CHEXX on Web (Chrome)..."

        # First, enable web support and clean any previous builds
        print_status "Enabling Flutter web support..."
        flutter config --enable-web

        print_status "Cleaning previous builds..."
        flutter clean
        flutter pub get

        # Build web version first to ensure all assets are compiled
        print_status "Building web version..."
        if ! flutter build web --web-renderer canvaskit --no-source-maps; then
            print_error "Web build failed. Trying with HTML renderer..."
            if ! flutter build web --web-renderer html --no-source-maps; then
                print_error "Web build failed with both renderers."
                exit 1
            fi
        fi

        print_success "Web build completed successfully!"

        if command -v google-chrome &> /dev/null; then
            print_status "Starting Flutter web server for Chrome..."

            # Check and kill any process using port 8888
            check_and_kill_port_8888

            # Start the server in the background
            flutter run -d web-server --web-port=8888 --web-hostname=localhost --release &
            SERVER_PID=$!

            # Wait for server to start
            print_status "Waiting for web server to initialize..."
            sleep 5

            # Check if server is responding
            for i in {1..10}; do
                if curl -s http://localhost:8888 > /dev/null 2>&1; then
                    print_success "Web server is ready!"
                    break
                elif [[ $i -eq 10 ]]; then
                    print_error "Web server failed to start properly"
                    kill $SERVER_PID 2>/dev/null
                    exit 1
                fi
                sleep 2
            done

            print_success "Opening Chrome to http://localhost:8888"
            google-chrome http://localhost:8888 &

            # Keep the server running
            wait $SERVER_PID
        else
            print_warning "Chrome not found, using default web browser"

            # Check and kill any process using port 8888
            check_and_kill_port_8888

            flutter run -d web-server --web-port=8888 --web-hostname=localhost --release
        fi
        ;;
    2)
        print_status "Launching CHEXX with Python HTTP server..."
        ./serve_web.sh
        ;;
    3)
        print_status "Launching CHEXX on Desktop (Linux)..."
        # Enable desktop support
        flutter config --enable-linux-desktop
        flutter run -d linux
        ;;
    4)
        print_status "Launching CHEXX on Android..."
        flutter run -d android
        ;;
    5)
        print_status "Available devices:"
        flutter devices
        echo ""
        read -p "Enter device ID to launch on (or press Enter to cancel): " device_id
        if [[ -n "$device_id" ]]; then
            flutter run -d "$device_id"
        else
            print_status "Launch cancelled"
        fi
        ;;
    *)
        print_error "Invalid choice. Exiting."
        exit 1
        ;;
esac

print_success "🎯 CHEXX game launch completed!"

# Display game info
echo ""
echo "🎮 GAME CONTROLS:"
echo "- Tap units to select them"
echo "- Tap highlighted hexes to move"
echo "- Tap enemy units to attack"
echo "- Use UI buttons to end turn or pause"
echo "- Purple hexes are Meta hexagons with special abilities"
echo ""
echo "🏆 OBJECTIVE:"
echo "- Eliminate all enemy units to win"
echo "- Each turn has a 6-second timer"
echo "- Faster decisions earn more reward points"
echo ""
echo "Have fun playing CHEXX! 🎯"