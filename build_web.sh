#!/bin/bash

# Build CHEXX for web deployment
echo "🌐 Building CHEXX for Web..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${YELLOW}[BUILD]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Enable web support
print_status "Enabling Flutter web support..."
flutter config --enable-web

# Clean previous builds
print_status "Cleaning previous builds..."
flutter clean

# Get dependencies
print_status "Getting dependencies..."
flutter pub get

# Try building with CanvasKit first (better performance)
print_status "Building with CanvasKit renderer..."
if flutter build web --web-renderer canvaskit --release; then
    print_success "✅ Web build completed with CanvasKit renderer!"
    RENDERER="CanvasKit"
else
    print_error "❌ CanvasKit build failed, trying HTML renderer..."

    # Fallback to HTML renderer
    print_status "Building with HTML renderer..."
    if flutter build web --web-renderer html --release; then
        print_success "✅ Web build completed with HTML renderer!"
        RENDERER="HTML"
    else
        print_error "❌ Both renderers failed. Check errors above."
        exit 1
    fi
fi

# Display build info
echo ""
echo "🎉 Build Summary:"
echo "   Renderer: $RENDERER"
echo "   Output: build/web/"
echo "   Ready to deploy!"
echo ""

# Check if build directory exists and has content
if [[ -d "build/web" ]] && [[ -f "build/web/index.html" ]]; then
    print_success "Build artifacts verified ✅"
    echo "📁 Build contents:"
    ls -la build/web/ | head -10

    # Check for main.dart.js (or equivalent)
    if ls build/web/main.dart.js* &> /dev/null 2>&1; then
        print_success "✅ JavaScript files generated successfully"
    else
        print_error "⚠️  Warning: JavaScript files may not be generated properly"
    fi
else
    print_error "❌ Build directory missing or incomplete"
    exit 1
fi

echo ""
echo "🚀 To serve locally:"
echo "   cd build/web && python3 -m http.server 9090"
echo "   Then open Firefox to http://localhost:9090"