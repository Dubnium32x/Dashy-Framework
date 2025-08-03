#!/bin/bash
# setup_tileset.sh
# Script to set up the correct directory structure for tilesets

# Create directory structure
echo "Creating directory structure..."
mkdir -p sprites/tileset

# Copy tileset files
echo "Copying tileset files..."
cp source/sprites/tileset/*.png sprites/tileset/

echo "Done! Files copied to sprites/tileset/"
ls -la sprites/tileset/
