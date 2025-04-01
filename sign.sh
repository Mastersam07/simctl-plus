#!/bin/bash

# Build the project
swift build

# Get the path to the binary
BINARY_PATH=".build/debug/simctl-plus"
ENTITLEMENTS_PATH="Sources/simctl-plus/simctl-plus.entitlements"

# Sign the binary with entitlements
codesign --force --sign - --entitlements "$ENTITLEMENTS_PATH" "$BINARY_PATH"

echo "Binary signed with entitlements" 