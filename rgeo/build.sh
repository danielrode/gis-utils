#!/usr/bin/env bash
# Author: Daniel Rode
# Dependencies:
#   bash 4+
#   podman 5.1.2


CONTAINER_NAME="rgeo:v1"


# Decide whether to use Docker or Podman
container_manager=podman

# Build container
cd "$(dirname "$0")"
$container_manager build --tag "$CONTAINER_NAME" .
