#!/usr/bin/env bash
# Author: Daniel Rode
# Dependencies:
#   bash 4+
#   podman 5.1.2


CONTAINER_NAME="rgeo:v2"
CONTAINER_MANAGER=podman


# Build container
cd "$(dirname "$0")"
$CONTAINER_MANAGER build --tag "$CONTAINER_NAME" .
