#!/bin/bash

# Flutter PATH setup script for CHEXX
# Source this script to add Flutter to your PATH: source ./setup_flutter_path.sh

echo "🔧 Setting up Flutter PATH..."

# Common Flutter installation locations
FLUTTER_LOCATIONS=(
    "$HOME/development/flutter/bin"
    "$HOME/flutter/bin"
    "/opt/flutter/bin"
    "/usr/local/flutter/bin"
    "/snap/flutter/current/bin"
)

# Check if Flutter is already in PATH
if command -v flutter &> /dev/null; then
    echo "✅ Flutter is already available in PATH: $(which flutter)"
    flutter --version
    return 0 2>/dev/null || exit 0
fi

# Try to find Flutter in common locations
for location in "${FLUTTER_LOCATIONS[@]}"; do
    if [[ -f "$location/flutter" ]]; then
        echo "📍 Found Flutter at: $location"
        export PATH="$PATH:$location"

        if command -v flutter &> /dev/null; then
            echo "✅ Flutter added to PATH successfully!"
            echo "📋 Flutter location: $(which flutter)"
            flutter --version

            # Add to current shell profile
            SHELL_RC=""
            if [[ "$SHELL" == *"zsh"* ]]; then
                SHELL_RC="$HOME/.zshrc"
            elif [[ "$SHELL" == *"bash"* ]]; then
                SHELL_RC="$HOME/.bashrc"
            else
                SHELL_RC="$HOME/.profile"
            fi

            if [[ -n "$SHELL_RC" ]] && [[ -f "$SHELL_RC" ]] && ! grep -q "$location" "$SHELL_RC"; then
                echo "export PATH=\"\$PATH:$location\"" >> "$SHELL_RC"
                echo "💾 Added Flutter to $SHELL_RC for future sessions"
            fi

            return 0 2>/dev/null || exit 0
        fi
    fi
done

echo "❌ Flutter not found in common locations."
echo "🔧 Please install Flutter or run ./start.sh to auto-install"
echo ""
echo "Common installation locations checked:"
for location in "${FLUTTER_LOCATIONS[@]}"; do
    echo "  - $location"
done

return 1 2>/dev/null || exit 1