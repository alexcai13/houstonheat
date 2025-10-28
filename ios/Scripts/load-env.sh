#!/bin/bash

# Script to inject environment variables into iOS build
# This reads from .env and sets Xcode environment variables

set -e

# Path to .env file
ENV_FILE="${SRCROOT}/../../.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found at $ENV_FILE"
    echo "Please create a .env file with MAPBOX_ACCESS_TOKEN"
    exit 1
fi

# Read MAPBOX_ACCESS_TOKEN from .env
MAPBOX_TOKEN=$(grep '^MAPBOX_ACCESS_TOKEN=' "$ENV_FILE" | cut -d '=' -f2-)

if [ -z "$MAPBOX_TOKEN" ]; then
    echo "Error: MAPBOX_ACCESS_TOKEN not found in .env file"
    exit 1
fi

# Export for use in Info.plist
export MAPBOX_ACCESS_TOKEN="$MAPBOX_TOKEN"

echo "✅ Mapbox token loaded from .env"
