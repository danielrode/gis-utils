#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Author: Daniel Rode
# Tags:
# Dependencies:
#   python 3.7+
# Created:
# Updated: -
# Version: 0


# Description: ...


import os
import sys
import pathlib as pl
from sys import exit


# Variables
EXE_NAME = sys.argv[0].split('/')[-1]  # This script's filename
HELP_TEXT = f"Usage: {EXE_NAME} [OPTION]... ARG"


# Main
def main():
    # Parse arguments
    # *example code
    args = iter(sys.argv[1:])
    for i in args:
        if i in ['-p', '--path']:
            path = next(args)

    # Read content from file if path is provided, otherwise, read from stdin
    try:
        path = pl.Path(sys.argv[1])
    except IndexError:
        file_content = sys.stdin.read()
    else:
        with open(path, 'r') as f:
            file_content = f.read()

    # Use concurrency via parallelism
    from concurrent.futures import ProcessPoolExecutor

    def go(func, value):
        executor = ProcessPoolExecutor(max_workers=1)
        worker = executor.submit(func, value)
        executor.shutdown(wait=False)

        return worker

    worker = go(sum, [1,2,3,4])  # non-blocking
    result = worker.result()  # blocking


if __name__ == '__main__':
    main()



"""
TODO
- task 1
- task 2
- ...
"""
