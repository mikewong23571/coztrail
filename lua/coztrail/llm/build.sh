#!/bin/bash
echo "Building summary tool for Unix/Linux/macOS..."
go build -o summary summary.go
if [ $? -eq 0 ]; then
    echo "Build successful! summary created."
    chmod +x summary
else
    echo "Build failed!"
    exit 1
fi