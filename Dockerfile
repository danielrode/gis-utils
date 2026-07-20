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
        R \
        fftw-double-libs \
        gdal \
        gdal-tools \
        pdal \
        proj-util \
        python3 \
        udunits \
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

    apk add \
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

    apk add \
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

RUN rinstall r-lidar/rlas r-lidar/lidR

# Install lasR
RUN rinstall r-lidar/lasR

# Install lidRmetrics
RUN rinstall geometry
RUN rinstall Lmoments
RUN rinstall pak
RUN rinstall github::ptompalski/lidRmetrics

# Make sure all system dependencies are installed
RUN Rscript - <<'EOF'
deps = pak::sysreqs_check_installed()
if (any(!deps$installed)) stop(deps)
EOF


############################################################################
# -- PDAL WRENCH BUILD IMAGE --
############################################################################

# Image for installing and building R packages

FROM base0 AS builder_wrench

# Install Alpine Linux packages for building PDAL Wrench
RUN ash <<'EOF'
    set -e  # Exit on error

    apk add \
        cmake \
        g++ \
        git \
        libzip-dev \
        make \
        pdal-dev \
    ;

    # Build and install PDAL Wrench from source
    git clone "https://github.com/PDAL/wrench"
    mkdir wrench/build
    cd wrench/build
    cmake ..
    make

    mv pdal_wrench /usr/local/bin/pdal_wrench
EOF


###############################################################################
# -- LASTOOLS "BUILD" IMAGE --
############################################################################

FROM base0 AS builder_lastools

# Install Alpine Linux packages for building LAStools
RUN apk add \
    build-base \
    cmake \
    git \
    libgeotiff-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libwebp-dev \
    proj-dev \
    sqlite-dev \
    tiff-dev \
    xz-dev \
    zlib-dev \
    zstd-dev \
;

# Compile LAStools
RUN git clone https://github.com/LAStools/LAStools
RUN cd /LAStools && cmake -DCMAKE_BUILD_TYPE=Release CMakeLists.txt
RUN cd /LAStools && cmake --build .

# Install LAStools
RUN cd /LAStools/bin64 && find . -type f -name '*64' \
    | xargs basename -a \
    | sed 's/64$//' \
    | xargs -I@ ln -sv @64 @ \
;


###############################################################################
# -- FINAL IMAGE --
############################################################################

FROM base0

# Install Alpine Linux packages
RUN ash <<'EOF'
    set -e  # Exit on error
    apk add --no-cache \
        bash \
        file \
        fish \
        helix \
        fd \
        libzip \
        openssh \
        parallel \
        ripgrep \
    ;
EOF

# Install binary dependencies from sister containers
COPY --from=builder_wrench /usr/local/bin/pdal_wrench /usr/local/bin/
COPY --from=builder_r /usr/local/rlib /usr/local/rlib
COPY --from=builder_py /usr/local/pylib /usr/local/pylib
COPY --from=builder_lastools /LAStools/bin64 /opt/lastools/bin

ENV R_LIBS_USER=/usr/local/rlib

# Install scripts from this repo
COPY bin /vogeler/bin
COPY lib /vogeler/lib

ENV PYTHONPATH="/vogeler/lib/py"
ENV PATH="/vogeler/bin:/usr/local/pylib/bin:$PATH:/opt/lastools/bin"
