#!/bin/bash

# Exit on any error
set -e

echo "Removing .dart_tool/pub/bin..."
rm -rf .dart_tool/pub/bin

echo "Activating package globally..."
dart pub global activate --source path .

echo "Installation complete. You can now run 'serverpod_vps' from anywhere." 