# author: daniel rode


# https://docs.docker.com/reference/dockerfile/


###############################################################################
# -- FOUNDATION IMAGE --
############################################################################

# Image used as base by all future stages

FROM docker.io/alpine:edge AS base0

LABEL Author="Daniel Rode"

# Install Alpine Linux packages
RUN ash <<'EOF'
    set -e  # Exit on error

    apk add --no-cache \
        gdal \
        R \
        proj-util \
        python3 \
    ;
EOF


###############################################################################
# -- PYTHON BUILD IMAGE --
############################################################################

# Image for installing and building Python packages

FROM base0 AS builder_py

# Install Alpine Linux packages for building Python libraries
RUN ash <<'EOF'
    set -e  # Exit on error

    apk add --no-cache \
        g++ \
        gcc \
        gdal-dev \
        geos-dev \
        make \
        proj-dev \
        proj-data \
        py3-pip \
        python3-dev \
        R-dev \
    ;
EOF

# Setup install destination for Python libraries
RUN python3 -m venv /usr/local/pylib
RUN /usr/local/pylib/bin/python3 -m pip install --upgrade pip

# Build and download Python libraries via pip
RUN /usr/local/pylib/bin/python3 -m pip install  geopandas
RUN /usr/local/pylib/bin/python3 -m pip install  pathos
RUN /usr/local/pylib/bin/python3 -m pip install  rasterio
RUN /usr/local/pylib/bin/python3 -m pip install  rasterstats
RUN /usr/local/pylib/bin/python3 -m pip install  rpy2
RUN /usr/local/pylib/bin/python3 -m pip install  scikit-learn
RUN /usr/local/pylib/bin/python3 -m pip install  seaborn
RUN /usr/local/pylib/bin/python3 -m pip install  xmltodict
RUN /usr/local/pylib/bin/python3 -m pip install  contextily
RUN /usr/local/pylib/bin/python3 -m pip install  xyzservices
RUN /usr/local/pylib/bin/python3 -m pip install  laspy[lazrs]
RUN /usr/local/pylib/bin/python3 -m pip install  openpyxl
RUN /usr/local/pylib/bin/python3 -m pip install  ipython


###############################################################################
# -- R BUILD IMAGE --
############################################################################

# Image for installing and building R packages

FROM base0 AS builder_r

# Install Alpine Linux packages for building R libraries
RUN ash <<'EOF'
    set -e  # Exit on error

    apk add --no-cache \
        abseil-cpp-dev \
        boost-dev \
        fftw-dev \
        fontconfig-dev \
        fribidi-dev \
        g++ \
        gdal-dev \
        geos-dev \
        harfbuzz-dev \
        libgit2-dev \
        libjpeg-turbo-dev \
        libuv-dev \
        libxml2-dev \
        linux-headers \
        proj-dev \
        R-dev \
        tiff-dev \
        udunits-dev \
    ;
EOF

# Setup script for installing R packages
RUN Rscript -e 'install.packages("pak", repo="https://cran.rstudio.com")'

COPY <<'EOF' /bin/rinstall
#!/usr/bin/env Rscript
library(pak)

args = commandArgs(trailingOnly=TRUE)

# Do not automatically install system package dependencies
# NOTE: Pak will still say that it is going to install system packages, but
# it will still skip the command call anyway.
options(pak.sysreqs=FALSE)

# Install package
pak::pkg_install(args, lib='/usr/local/rlib')

# TODO somehow check this before package install
# # Halt and tell user if required system packages are missing
# out = pak::sysreqs_check_installed(args)
# if (any(!out$installed)) stop(out)
EOF
RUN chmod +x /bin/rinstall
RUN mkdir -p /usr/local/rlib

ENV R_LIBS_USER=/usr/local/rlib

# Install lidR
RUN rinstall sp
RUN rinstall codetools  # Recommended for building lidR
RUN rinstall doParallel  # Needed for parallel processing
RUN rinstall foreach  # Needed for parallel processing
RUN rinstall future  # Needed to enable lidR parallel processing
RUN rinstall rjson  # Needed for loading LAS catalog RDS objects
RUN rinstall lwgeom  # Needed for crown statistics
RUN rinstall tibble  # Needed by SF for loading certain vector formats

RUN rinstall bioc::EBImage

# TODO merge to above then rm
COPY <<'EOF' /bin/rinstall
#!/usr/bin/env Rscript
library(pak)

args = commandArgs(trailingOnly=TRUE)

# Do not automatically install system package dependencies
# NOTE: Pak will still say that it is going to install system packages, but
# it will still skip the command call anyway.
options(pak.sysreqs=FALSE)

# Install package
pak::pkg_install(args, lib='/usr/local/rlib')
EOF
RUN chmod +x /bin/rinstall

RUN rinstall r-lidar/rlas r-lidar/lidR

# Install lasR
RUN rinstall r-lidar/lasR

# Install lidRmetrics
RUN rinstall geometry
RUN rinstall Lmoments
RUN rinstall pak
RUN rinstall github::ptompalski/lidRmetrics

# Make sure all system dependencies are installed
RUN Rscript -e '\
deps = pak::sysreqs_check_installed(); \
if (any(!deps$installed)) stop(deps); '


###############################################################################
# -- LASTOOLS "BUILD" IMAGE --
############################################################################

FROM base0 AS builder_lastools

# Download and install LAStools
RUN wget -O /lt.tgz https://downloads.rapidlasso.de/LAStools.tar.gz && \
    hash="$(sha1sum </lt.tgz | cut -f1 -d' ')" && \
    test "$hash" = dcc1679426e6e7eb04e81bff3937b71d075d8cac
RUN mkdir /opt/lastools
RUN tar xf /lt.tgz --directory /opt/lastools
RUN mkdir /opt/lastools/docs
RUN mv -v /opt/lastools/bin/*.md /opt/lastools/docs/
RUN chmod 755 /opt/lastools
RUN find /opt/lastools/ -type d | xargs chmod 755
RUN find /opt/lastools/ -type f | xargs chmod 644
RUN find /opt/lastools/bin -type f | xargs chmod 755
RUN find /opt/lastools/bin/ -print0 -type f -maxdepth 1 -name '*64' | \
    xargs -0 -I@ sh -c 'ln -sv "$1" "$(echo "$1" | sed "s/64$//")"' '' @

# TODO lastool binaries are missing runtime dependencies


###############################################################################
# -- FINAL IMAGE --
############################################################################

FROM base0

# Install Alpine Linux packages
RUN ash <<'EOF'
    set -e  # Exit on error
    apk add --no-cache \
        R \
        bash \
        file \
        fish \
        helix \
        fd \
        fftw-double-libs \
        gdal-tools \
        openssh \
        parallel \
        pdal \
        proj-util \
        python3 \
        ripgrep \
        udunits \
    ;
EOF

# Install binary dependencies from sister containers
COPY --from=ghcr.io/vogelerlab/pdal_wrench:main \
    /usr/local/bin/pdal_wrench /usr/local/bin/pdal_wrench

COPY --from=builder_r /usr/local/rlib /usr/local/rlib
COPY --from=builder_py /usr/local/pylib /usr/local/pylib
COPY --from=builder_lastools /opt/lastools /opt/lastools

ENV R_LIBS_USER=/usr/local/rlib

# Install scripts from this repo
COPY bin /vogeler/bin
COPY lib /vogeler/lib

ENV PYTHONPATH="/vogeler/lib/py"
ENV PATH="/vogeler/bin:/usr/local/pylib/bin:$PATH:/opt/lastools/bin"
