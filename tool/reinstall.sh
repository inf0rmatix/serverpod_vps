#!/bin/bash

# Exit on any error
set -e

echo "Removing .dart_tool/pub/bin..."
rm -rf .dart_tool/pub/bin

# Set development assets path
export SERVERPOD_VPS_ASSETS="$(dirname "$0")/../assets/templates"
echo "SERVERPOD_VPS_ASSETS: $SERVERPOD_VPS_ASSETS"

echo "Activating package globally..."
dart pub global activate --source path "$(dirname "$0")/.."

echo "Installation complete. You can now run 'serverpod_vps' from anywhere."
echo "Development assets path: $SERVERPOD_VPS_ASSETS"