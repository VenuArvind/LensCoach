#!/bin/bash

# LensCoach Model Setup Script
# This script downloads the required 2.2GB LLM model and places it in the correct Resources directory.

RESOURCES_DIR="LensCoachApp/Sources/Resources"
PHI3_URL="https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf"

echo "🎯 Starting LensCoach Model Setup..."

# Create directory if it doesn't exist
mkdir -p "$RESOURCES_DIR"

# Download Phi-3 Model
if [ ! -f "$RESOURCES_DIR/Phi-3-mini-4k-instruct-q4.gguf" ]; then
    echo "⬇️ Downloading Phi-3 Mini (2.2GB)... This may take a few minutes."
    curl -L "$PHI3_URL" -o "$RESOURCES_DIR/Phi-3-mini-4k-instruct-q4.gguf"
else
    echo "✅ Phi-3 model already exists."
fi

echo "✨ Setup complete! You can now open LensCoachNative/LensCoachNative.xcodeproj and build the app."
