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

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed or not in PATH"
    print_status "Installing Flutter..."

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

    # Add to PATH for this session
    export PATH="$PATH:$HOME/development/flutter/bin"

    # Add to bashrc for future sessions
    if ! grep -q "flutter/bin" ~/.bashrc; then
        echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.bashrc
        print_status "Added Flutter to ~/.bashrc"
    fi

    cd - > /dev/null
    print_success "Flutter installed successfully"
else
    print_success "Flutter is already installed"
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
echo "1) Web (Firefox) - Recommended for development"
echo "2) Desktop (Linux)"
echo "3) Android (if device/emulator connected)"
echo "4) Check available devices"

read -p "Enter choice (1-4) [default: 1]: " choice
choice=${choice:-1}

case $choice in
    1)
        print_status "Launching CHEXX on Web (Firefox)..."
        if command -v firefox &> /dev/null; then
            # Set Firefox as the default browser for Flutter web
            export CHROME_EXECUTABLE=$(which firefox)
            flutter run -d chrome --web-port=9090 --web-hostname=localhost
        else
            print_warning "Firefox not found, using default web browser"
            flutter run -d web-server --web-port=9090 --web-hostname=localhost
        fi
        ;;
    2)
        print_status "Launching CHEXX on Desktop (Linux)..."
        # Enable desktop support
        flutter config --enable-linux-desktop
        flutter run -d linux
        ;;
    3)
        print_status "Launching CHEXX on Android..."
        flutter run -d android
        ;;
    4)
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