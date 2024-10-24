# Author: Daniel Rode
# Dependencies:
#   podman 5.1.2
# Created: 24 Oct 2024
# Updated: -


# https://docs.docker.com/reference/dockerfile/


LABEL Author="Daniel Rode"
LABEL Version="1"


# Set base image
FROM rocker/geospatial:4.4.1

# Build and install software/dependencies
RUN Rscript - <<'EOF'
  install.packages(
    c("lidR"),
    repos = "https://cran.rstudio.com"
  )
EOF
