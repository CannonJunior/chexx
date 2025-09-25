#!/bin/bash

# Simple compilation test for CHEXX
echo "🧪 Testing CHEXX compilation..."

# Check if we can analyze without errors
echo "📋 Running Flutter analyze..."
if flutter analyze --no-pub; then
    echo "✅ Static analysis passed"
else
    echo "❌ Static analysis failed"
    exit 1
fi

# Try to compile for web
echo "🌐 Testing web compilation..."
if flutter build web --release --no-pub; then
    echo "✅ Web compilation successful"
else
    echo "❌ Web compilation failed"
    exit 1
fi

echo "🎉 All compilation tests passed!"