#!/bin/bash
echo "Building summary tool for all platforms..."

# Windows
echo "Building for Windows..."
GOOS=windows GOARCH=amd64 go build -o summary.exe summary.go

# Linux
echo "Building for Linux..."
GOOS=linux GOARCH=amd64 go build -o summary-linux summary.go

# macOS
echo "Building for macOS..."
GOOS=darwin GOARCH=amd64 go build -o summary-macos summary.go

echo "All builds completed!"
ls -la summary*