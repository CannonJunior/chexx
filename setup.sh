#!/bin/bash

# CHEXX Flutter Setup Script
echo "🎯 Setting up CHEXX Flutter project..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "📦 Installing Flutter..."

    # Download Flutter
    cd /tmp
    wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.3-stable.tar.xz
    tar xf flutter_linux_3.24.3-stable.tar.xz

    # Move to opt directory
    sudo mv flutter /opt/

    # Add to PATH
    echo 'export PATH="$PATH:/opt/flutter/bin"' >> ~/.bashrc
    export PATH="$PATH:/opt/flutter/bin"

    echo "✅ Flutter installed"
else
    echo "✅ Flutter already installed"
fi

# Return to project directory
cd /home/junior/src/chexx

# Create Flutter project structure manually since we're in existing directory
echo "🏗️ Setting up Flutter project structure..."

# Create pubspec.yaml
cat > pubspec.yaml << 'EOF'
name: chexx
description: "A hexagonal turn-based strategy game built with Flutter and Flame."
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.5.0
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter
  flame: ^1.18.0
  flame_forge2d: ^0.16.0
  cupertino_icons: ^1.0.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/config/
EOF

# Create basic directory structure
mkdir -p lib/src/{models,components,systems,screens,utils,config}
mkdir -p assets/{images,config}
mkdir -p test

echo "📋 Project structure created"
echo "🔄 Getting Flutter dependencies..."

# Get dependencies
flutter pub get

echo "✅ CHEXX project setup complete!"
echo "🚀 Run './start.sh' to launch the game"