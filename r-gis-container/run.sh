#!/usr/bin/env bash
# Author: Daniel Rode
# Dependencies:
#   bash 4+
#   podman 5.1.2


CONTAINER_MANAGER=podman


# Run container
$CONTAINER_MANAGER run -it --rm \
  -v "/home/$USER:/home/$USER" \
  -v "/mnt:/mnt" \
  localhost/rgeo:v2 \
  bash -c "cd $PWD; exec R --no-save" \
;
