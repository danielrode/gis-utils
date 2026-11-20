#!/usr/bin/env bash
# author: daniel rode
# dependencies:
#   podman 5.8.9
#   git


###############################################################################
# -- Configure Shell --
#############################################################################

# Exit on error
set -e

# Set working directory to where this script is
cd "$(dirname "$0")"

# Log output
exec > >(tee "$(basename "$0").log") 2>&1


###############################################################################
# -- Main --
#############################################################################

# Build main container
echo "Building container..."
git_commit="$(git rev-parse HEAD . | head -1)"
podman build \
    --tag "gis-utils:latest" \
    . \
;
podman tag gis-utils:latest gis-utils:main

# Publish image
echo 'To publish image:
podman push gis-utils:main ghcr.io/danielrode/gis-utils:main
podman push gis-utils:latest ghcr.io/danielrode/gis-utils:latest
podman pull ghcr.io/danielrode/gis-utils:main
podman pull ghcr.io/danielrode/gis-utils:latest
'
