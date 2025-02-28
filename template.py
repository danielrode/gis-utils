#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Author: Daniel Rode
# Tags:
# Dependencies:
#   python 3.10+
#   pdal_wrench
#   gdalbuildvrt
# Created:
# Updated: -
# Version: 0


# Description: ...


# Import standard libraries
import os
import sys
import logging
import datetime
import functools
import subprocess as sp
from sys import exit
from pathlib import Path
from tempfile import NamedTemporaryFile
from tempfile import TemporaryDirectory
from concurrent.futures import ProcessPoolExecutor
from concurrent.futures import as_completed as cf_as_completed

from typing import Any
from typing import Optional
from collections.abc import Callable
from collections.abc import Iterator

# Import external libraries
import dill
import shapely
import pyogrio
from geopandas import GeoDataFrame
from pathos.pools import ProcessPool

# Import R libraries
from rpy2.robjects.packages import importr
from rpy2.rinterface_lib.callbacks import logger as rpy2_logger
rbase = importr("base")
rmethods = importr("methods")
rpy2_logger.setLevel(logging.ERROR)  # Suppress R warning messages


# Constants
EXE_NAME = sys.argv[0].split('/')[-1]  # This script's filename
HELP_TEXT = f"Usage: {EXE_NAME} [OPTION]... ARG"

HOME = Path.home()
OUT_DIR = Path("./export")

MAX_WORKERS = os.cpu_count()

REPO_PATH = "PATH/TO/GIT/REPO"
REPO_COMMIT = "GIT_COMMIT_HASH"
DEPENDENCIES_FROM_REPO = (
    # These paths are relative to the repo path
    "PATH/TO/REPO/FILE1",
    "PATH/TO/REPO/FILE2",
    # ...
)


# Functions
def cd0() -> None:
    """Change directory to the parent path of this script file."""
    this_dir = sys.path[0]  # Dir where this script resides
    os.chdir(this_dir)

def print2(*args, **kwargs) -> None:
    """Print message to stderr."""
    print(*args, **kwargs, file=sys.stderr)

def timestamp() -> str:
    """Return current date and time as string."""
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M")

def lsdir(d: Path) -> Iterator[Path]:
    """
    Return a iterable list of paths for the given directory, skipping hidden
    files.
    """
    for i in d.iterdir():
        if not i.name.startswith("."):
            yield i

def get_path_stem(path: Path) -> str:
    """
    Pathlib .stem method only removes one file extension. This function
    removes them all.
    """
    path = Path(path)
    while True:
        path_stem = Path(path.stem)
        if path == path_stem:
            return str(path_stem)
        path = path_stem

def init_logger(
    path: Path = None, level = logging.INFO, capture_exceptions = True,
) -> logging.Logger:
    """Initialize logger, set format, and set verbosity level."""
    fmt = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
    logger = logging.getLogger()
    logger.setLevel(level)

    # Set logger to output to stderr
    console = logging.StreamHandler()
    console.setFormatter(fmt)
    logger.addHandler(console)

    # Set logger to output to a file as well
    if path:
        file = logging.FileHandler(path, mode='a')
        file.setFormatter(fmt)
        logger.addHandler(file)

    # Capture unhandled exceptions
    if capture_exceptions:
        sys.excepthook = lambda e_type, e_val, e_traceback: logger.critical(
            "Program terminating:", exc_info=(e_type, e_val, e_traceback)
        )

    return logger

def papply(jobs: iter, worker: Callable, max_workers=MAX_WORKERS) -> list:
    """
    Parallel apply dispatching function: Run a list of jobs with a given
    worker function, in parallel, and return the results in order of jobs
    list. Uses pathos as backend.
    """
    # Run workers in parallel
    with ProcessPool(ncpus=max_workers) as executor:
        try:
            results = executor.map(worker, jobs)
        except Exception as e:
            # If Python is sent a kill signal, kill all the workers too
            executor.terminate()
            raise e

    return results

def papply_native(
    jobs: iter, worker: Callable, max_workers=MAX_WORKERS,
) -> list:
    """
    Parallel apply dispatching function: Run a list of jobs with a given
    worker function, in parallel, and return the results in order of jobs
    list. Uses concurrent.futures as backend.
    """
    futures = []
    with ProcessPoolExecutor(max_workers=max_workers) as executor:
        futures = [executor.submit(worker, j) for j in jobs]
        results = [f.result() for f in futures]

    return results

def run_dill(fn: Callable, *args, **kwargs) -> Any:
    """
    Helper function to use dill instead of pickle so multiprocessing can
    accept lambda functions.
    """
    return dill.loads(fn)(*args, **kwargs)

def dispatch(
    jobs: iter, worker: Callable, max_workers=MAX_WORKERS,
) -> Iterator[(Any, Any)]:
    """
    Parallel apply dispatching function: Run a list of jobs with a given
    worker function, in parallel, and yield worker results in order they
    finish.
    """
    worker = functools.partial(run_dill, dill.dumps(worker))  # Allow lambdas
    with ProcessPoolExecutor(max_workers=max_workers) as executor:
        futures_jobs = {executor.submit(worker, j): j for j in jobs}
        for f in cf_as_completed(futures_jobs):
            log.info(f"Worker finished: {futures_jobs[f]}")
            yield (futures_jobs[f], f.result())

def cmd_pipe(cmds, stdin=None) -> None:
    """
    Run several system commands and pipe the output from one to the stdin
    of the next.
    """
    # Chain stdin and stdout of given commands together
    proc_list = []
    last_stdout = stdin
    for c in cmds:
        p = sp.Popen(c, stdin=last_stdout, stdout=sp.PIPE)
        proc_list.append(p)
        last_stdout = p.stdout

    # Print output of the last program in the chain
    while p.poll() is None:
        print(str(p.stdout.readline(), 'utf8'), end='')

    # Run commands and make sure none fail
    # stdout, stderr = p.communicate(input=stdin)
    for p in proc_list:
        p.wait()
        if p.returncode != 0:
            raise Exception("Subprocess command failed:", p.args)

    # if stdout:
    #     stdout = str(stdout, 'utf8').strip()
    # if stderr:
    #     stderr = str(stderr, 'utf8').strip()

    # return stdout, stderr

def import_scripts(
    repo_path: Path, repo_commit: str, repo_assets: list[Path], dst_dir: Path,
) -> None:
    """Use git to copy dependency scripts to another directory."""
    log.info(f"Git repo path: {repo_path}")
    log.info(f"Git repo commit: {repo_commit}")

    dst_dir.mkdir(parents=True, exist_ok=True)

    git_cmd = ('git',
        '-C', repo_path,
        'archive',
            '--format', 'tar',
            repo_commit,
            *repo_assets,
    )
    tar_cmd = ('tar',
        '--directory', str(dst_dir),
        '--file', '-',
        '--extract',
    )
    cmd_pipe([git_cmd, tar_cmd])

def gdal_build_vrt(src_paths: list[Path], dst_pth: Path) -> None:
    """Create virtual mosaic from a list of rasters."""
    with NamedTemporaryFile(suffix='.txt', buffering=0) as f:
        # Write list of source rasters to file
        for p in src_paths:
            f.write(bytes(p))
            f.write(b'\n')

        # Run GDAL to build virtual raster from source rasters
        cmd = ['gdalbuildvrt', '-input_file_list', f.name, dst_pth]
        sp.run(cmd, check=True)

def build_vpc(in_paths: list[Path], out_path: Path) -> None:
    """Create virtual mosaic from a list of point cloud files."""
    with NamedTemporaryFile() as tmp:
        # Save list of file paths to temp file to pass to PDAL Wrench
        for i in in_paths:
            tmp.write(bytes(f"{i}\n", 'utf8'))
        tmp.flush()

        # Run PDAL Wrench to build VPC
        log.info("Running PDAL Wrench...")
        cmd = (
            'pdal_wrench', 'build_vpc',
            '--input-file-list', tmp.name,
            '--output', out_path,
        )
        sp.run(cmd, check=True)

def rds2vpc(rds_path: Path, out_path: Path) -> None:
    """
    Extract list of source LAS/LAZ file paths from lidR las catalog object
    that was saved as an RDS file and build a virtual point cloud (VPC)
    catalog with that file set.
    """
    # Get set of LiDAR collection LAS/LAZ paths
    ctg = rbase.readRDS(rds_path)
    paths = rmethods.slot(ctg, 'data').rx2('filename')  # R: ctg@data$filename
    paths = set(paths)

    # Build VPC
    build_vpc(paths, out_path)

def wkt2gdf(wkt: str, crs: str) -> GeoDataFrame:
    """Create a GeoDataFrame from a WKT polygon string."""
    polygon = shapely.from_wkt(wkt)
    gdf = GeoDataFrame(geometry=[polygon], crs=crs)

    return gdf


# Main
def main() -> None:
    # Change directory to where this script resides
    cd0()

    # Setup logging
    global log
    log = init_logger("./main.log")

    # Parse command line arguments
    pos_args = []
    args = iter(sys.argv[1:])
    for a in args:
        if not a.startswith('-'):
            pos_args += [a] + list(args)
            break
        try:
            match a:
                case '-p' | '--path':
                    path = next(args)
                case '-d' | '--do':
                    do_the_thing = True
                case _:
                    print2("error: Invalid flag", a)
                    exit(1)
        except StopIteration:
            print2("error: Flag requires value:", a)
            exit(1)
        except ValueError:
            print2("error: Invalid value for flag:", a)
            exit(1)

    try:
        main_arg1 = Path(pos_args[0])
        main_arg2 = Path(pos_args[1])
    except IndexError:
        print2(HELP_TEXT)
        exit(1)

    for p in (main_arg1, main_arg2):
        if not p.exists():
            print2("error: Path does not exist:", p)
            exit(1)

    # Print start time
    log.info("Starting...")

    # Import dependency scripts
    log.info("Importing scripts...")
    scripts_dir = Path("./import/code")
    import_scripts(
        REPO_PATH, REPO_COMMIT, DEPENDENCIES_FROM_REPO, scripts_dir,
    )

    # Read content from file if path is provided, otherwise, read from stdin
    try:
        path = Path(sys.argv[1])
    except IndexError:
        file_content = sys.stdin.read()
    else:
        with open(path, 'r') as f:
            file_content = f.read()

    # Ensure product output directory exists
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # MAIN CODE
    log.info("DOING SOMETHING...")

    # Print end time
    log.info("Finished")


if __name__ == '__main__':
    main()



"""
TODO
- task 1
- task 2
- ...
"""
