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
        fontconfig-dev \
        fribidi-dev \
        g++ \
        gdal-dev \
        geos-dev \
        harfbuzz-dev \
        libgit2-dev \
        libxml2-dev \
        linux-headers \
        proj-dev \
        R-dev \
        udunits-dev \
    ;
EOF

# Create and setup script for installing R packages
# TODO consider using `pak::pkg_install("package_name")` or `install.packages("package_name", INSTALL_opts = "--clean")` instead
COPY <<'EOF' ./rinstall
#!/bin/sh
set -e  # Exit on error
repo="$2"
[ -z "$repo" ] && repo="https://cran.rstudio.com"
Rscript -e "install.packages('$1', repos='$repo', lib='/usr/local/rlib')"
Rscript -e "library($1, lib.loc='/usr/local/rlib')"  # Verify install
EOF

RUN ash <<'EOF'
    set -e  # Exit on error
    chmod +x ./rinstall
    mkdir -p /usr/local/rlib
EOF

# todo uncomment
# ENV R_LIBS_USER=/usr/local/rlib

# Install lidR
RUN ./rinstall sp
RUN ./rinstall codetools  # Recommended for building lidR
RUN ./rinstall doParallel  # Needed for parallel processing
RUN ./rinstall foreach  # Needed for parallel processing
RUN ./rinstall future  # Needed to enable lidR parallel processing
RUN ./rinstall rjson  # Needed for loading LAS catalog RDS objects
RUN ./rinstall lwgeom  # Needed for crown statistics
RUN ./rinstall tibble  # Needed by SF for loading certain vector formats

# todo: tmp workaround while lidr is off CRAN
    run apk add --no-cache libuv-dev
    run ./rinstall R6
    run ./rinstall askpass
    run ./rinstall credentials
    run ./rinstall openssl
    run ./rinstall sys
    run ./rinstall zip
    run ./rinstall gitcreds
    env R_LIBS_USER=/usr/local/rlib
    run ./rinstall httr2
    run ./rinstall ini
    run ./rinstall clipr
    run ./rinstall crayon
    run ./rinstall curl
    run ./rinstall desc
    run ./rinstall fs
    run ./rinstall gert
    run ./rinstall gh
    run ./rinstall jsonlite
    run ./rinstall purrr
    run ./rinstall rappdirs
    run ./rinstall rprojroot
    run ./rinstall rstudioapi
    run ./rinstall whisker
    run ./rinstall withr
    run ./rinstall yaml
    run ./rinstall usethis
    run ./rinstall fs
    run ./rinstall miniUI
    run ./rinstall pkgdown
    run ./rinstall pkgload
    run ./rinstall profvis
    run ./rinstall roxygen2
    run ./rinstall testthat
    run ./rinstall pak
    run R -e 'pak::pkg_install("url::https://cran.r-project.org/src/contrib/Archive/rlas/rlas_1.9.3.tar.gz")'
    run R -e 'pak::pkg_install("url::https://cran.r-project.org/src/contrib/Archive/lidR/lidR_4.3.2.tar.gz")'
	  run apk add --no-cache libjpeg-turbo-dev tiff-dev fftw-dev
	  run R -e 'install.packages("BiocManager", repos="https://cran.rstudio.com"); BiocManager::install("EBImage"); library("EBImage")'


# Install lasR
RUN ./rinstall lasR "https://r-lidar.r-universe.dev"

# Install lidRmetrics
RUN ./rinstall geometry
RUN ./rinstall Lmoments
RUN ./rinstall pak
RUN Rscript -e 'pak::pak("ptompalski/lidRmetrics")'


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
COPY --from=builder_r /usr/local/rlib /usr/local/rlib
COPY --from=builder_py /usr/local/pylib /usr/local/pylib

ENV R_LIBS_USER=/usr/local/rlib
ENV PATH="/usr/local/pylib/bin:$PATH"

COPY --from=ghcr.io/vogelerlab/pdal_wrench:main \
    /usr/local/bin/pdal_wrench /usr/local/bin/pdal_wrench
