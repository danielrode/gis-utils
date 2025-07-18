# gis-utils

Small simple UNIX-like utilities and functions to make working with geospatial data easier

## Usage

### Windows

```powershell
# PowerShell
podman machine init
podman machine start
podman run --rm -it --volume "$(get-location):/wd" --workdir "/wd" ghcr.io/vogelerlab/gis-utils:main
```

### Linux

```bash
# Bash
podman run --rm -it --volume '/tmp:/tmp' --volume '/mnt:/mnt' --volume '/home:/home' --volume "$PWD:$PWD" --workdir "$PWD" ghcr.io/vogelerlab/gis-utils:main
```
