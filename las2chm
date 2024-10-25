#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Author: Daniel Rode
# Dependencies:
#   python 3.12.6
#   pdal 2.6.3
#   gdal
# Created: 17 Sep 2024
# Updated: 18 Sep 2024


import sys
import json
import subprocess as sp
from sys import exit
from pathlib import Path
from datetime import datetime


HELP_TEXT = "Usage: lidar-chm.py  IN_LAS_PATH  OUT_TIFF_PATH"


def pdal(in_path, out_path):
  pipeline = [
    str(in_path),
    # Height normalize
    {
      "type":"filters.hag_delaunay",
    },
    {
      "type":"filters.ferry",
      "dimensions":"HeightAboveGround=>Z",
    },
    # Select first returns and points above 2 meters (assuming your CRS using
    # meters as its unit)
    #  {
    #    "type": "filters.expression",
    #    "expression": "(Z > 2) && (NumberOfReturns > 1 && ReturnNumber == 1)"
    #  },
    # Values are set to zero (instead of being filtered out) so GDAL does not
    # error out on empty pixels)
    {
      "type": "filters.assign",
      "value": [
        "Z = 0 WHERE Z < 2",
        "Z = 0 WHERE (NumberOfReturns > 1 && ReturnNumber != 1)",
      ],
    },
    # Generate CHM
    {
      "resolution": 0.5,
      "binmode": True,
      "dimension": "Z",
      # Available options: min, max, mean, idw, count, stdev, and all
      "output_type": ["max"],
      "gdaldriver": "GTiff",
      "filename": str(out_path),
     }
  ]
  cmd = [
    "pdal",
    "pipeline",
    "--stdin",
    "--nostream",
    "--progress", "./pdal.log",
  ]
  Path("./pdal.log").touch()
  sp.run(cmd, text=True, check=True, input=json.dumps(pipeline))


# Parse command line arguments
args = sys.argv[1:]
try:
  in_path = Path(args[0])
  out_path = Path(args[1])
except IndexError:
  print(HELP_TEXT)
  exit(1)

# Run PDAL
print(f"Starting {datetime.now()}")
pdal(in_path, out_path)
print(f"Finished {datetime.now()}")
