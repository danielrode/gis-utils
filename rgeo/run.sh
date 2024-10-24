#!/usr/bin/env bash
# Author: Daniel Rode
# Dependencies:
#   bash 4+
#   podman 5.1.2


# Decide whether to use Docker or Podman
container_manager=podman

# Run container
podman run -it --rm -v "/home/$USER:/home/$USER" localhost/rgeo:v1 \
  bash -c "cd $PWD; exec R --no-save"
