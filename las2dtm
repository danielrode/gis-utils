#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Author: Daniel Rode
# Dependencies:
#   python 3.12.6
#   pdal 2.6.3
#   gdal
# Created: 11 Oct 2024
# Updated: -


import sys
import json
import subprocess as sp
from sys import exit
from pathlib import Path
from datetime import datetime


HELP_TEXT = """Usage: this.py  IN_LAS_PATH  OUT_TIFF_PATH"""


def get_pdal_pipeline(in_path, out_path):
  return json.dumps([
    str(in_path),
    # Drop non-ground points
    {
      "type": "filters.expression",
      "expression": "Classification == 2",
    },
    # Generate DTM
    {
      "resolution": 0.5,
      "binmode": False,
      "dimension": "Z",
      "output_type": ["mean"],
      "gdaldriver": "GTiff",
      "filename": str(out_path),
     },
  ])

def pdal(pipeline_json):
  cmd = [
    "pdal",
    "pipeline",
    "--stdin",
    "--nostream",
  ]
  sp.run(cmd, text=True, check=True, input=pipeline_json)
  
def gdal_fill_nodata(in_path, out_path):
  cmd = [
    "gdal_fillnodata.py", "-md", "99", in_path, out_path
  ]
  sp.run(cmd, check=True)


# Parse command line arguments
args = sys.argv[1:]
try:
  in_path = Path(args[0])
  out_path = Path(args[1])
except IndexError:
  print(HELP_TEXT)
  exit(1)

# Generate DTM raster
print(f"Starting {datetime.now()}")
pdal(get_pdal_pipeline(in_path, "./tmp-dtm-partial.tif"))
gdal_fill_nodata("./tmp-dtm-partial.tif", out_path)
print(f"Finished {datetime.now()}")
