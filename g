#!/usr/bin/env bash
# Author: Daniel Rode
# Dependencies:
#   bash 4+


CON_IMG="localhost/rgeo:v2"
CON_CMD=(
    nice
        --adjustment 15
    podman run
        --rm
        --mount 'type=bind,src=/tmp,dst=/tmp'
        --mount 'type=bind,src=/mnt,dst=/mnt'
        --mount 'type=bind,src=/home,dst=/home'
        --workdir "$(pwd)"
        "$CON_IMG"
)


HERE_DIR="$(dirname $0)"
utility="$HERE_DIR"/"$1"
shift
"${CON_CMD[@]}" "$utility" "$@"
