#!/bin/bash
set -e

echo "Building agent-screenshot..."
swiftc -parse-as-library \
    src/main.swift \
    -framework ScreenCaptureKit \
    -framework CoreGraphics \
    -framework AppKit \
    -framework Foundation \
    -o agent-screenshot

echo "✓ Build complete: ./agent-screenshot"
