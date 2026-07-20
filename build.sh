#!/usr/bin/env bash
# author: daniel rode
# dependencies:
#   podman 5.8.4
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

# Use Podman instead of Docker
function docker {
    podman "$@"
}


###############################################################################
# -- Main --
#############################################################################

# Build main container
echo "Building container..."
git_commit="$(git rev-parse HEAD . | head -1)"
docker build \
    --tag "gis-utils:latest" \
    . \
;
docker tag gis-utils:latest gis-utils:dev

# Publish image
docker push gis-utils:dev ghcr.io/danielrode/gis-utils:dev
docker pull ghcr.io/danielrode/gis-utils:dev
