# syntax = docker/dockerfile:1.4.1

FROM 812206152185.dkr.ecr.us-west-2.amazonaws.com/lytectl:lytectl-cc67-kenny_lyte as flytectl

FROM 812206152185.dkr.ecr.us-west-2.amazonaws.com/latch-base:02ab-main

SHELL ["/usr/bin/env", "bash", "-c"]

# Allow --mount=cache to do its job
# https://github.com/moby/buildkit/blob/86c33b66e176a6fc74b88d6f46798d3ec18e2e73/frontend/dockerfile/docs/syntax.md#run---mounttypecache
RUN rm /etc/apt/apt.conf.d/docker-clean
RUN echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache


# Generic installation dependencies
# wget - obvious
# software-properties-common - `add-apt-repository`
# dirmngr - GPG key manager, loads from `/etc/apt/trusted.gpg.d/`
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
<<EOF
  set -o errexit

  apt-get update
  apt-get install --yes --no-install-recommends \
    wget \
    software-properties-common \
    dirmngr
EOF

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
<<EOF
  set -o errexit

  apt-get update
  apt-get install --yes --no-install-recommends \
    pandoc
EOF

#
# R
#

# >>> Install R
# https://cloud.r-project.org/bin/linux/debian/
# https://github.com/rocker-org/rocker-versioned2/blob/f3325b2cf88d8899ddcb2f0945aa9f87ad150cd7/scripts/install_R_ppa.sh
RUN <<EOF
  apt-key adv --keyserver keyserver.ubuntu.com --recv-key '95C0FAF38DB3CCAD0C080A7BDC78B2DDEABC47B7'

  debian_codename=$(lsb_release --codename --short)
  add-apt-repository "deb https://cloud.r-project.org/bin/linux/debian ${debian_codename}-cran40/"
EOF
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
<<EOF
  set -o errexit

  apt-get update
  apt-get install --yes \
    r-base \
    r-base-dev \
    locales

  # Do not auto-update R
  apt-mark hold r-base r-base-dev
EOF

RUN <<EOF
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen en_US.utf8
/usr/sbin/update-locale LANG="en_US.UTF-8"
EOF

# Configure binary package caches
COPY <<EOF /usr/local/lib/R/etc/RProfile.site
options(HTTPUserAgent = sprintf("R/%s R (%s)", getRversion(), paste(getRversion(), R.version["platform"], R.version["arch"], R.version["os"])))
EOF

# Install renv
ENV RENV_PATHS_CACHE="/var/cache/renv"
RUN --mount=type=cache,target=/var/cache/renv,sharing=locked \
<<EOF
#!/usr/bin/env Rscript
source("/usr/local/lib/R/etc/RProfile.site")
install.packages("remotes")
remotes::install_github("rstudio/renv@0.15.4")
EOF

# >>> R packages
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
<<EOF
  set -o errexit

  apt-get update
  apt install --yes \
    libcurl4-openssl-dev \
    libxml2-dev \
    libssl-dev
EOF

RUN --mount=type=cache,target=/var/cache/renv,sharing=locked \
<<EOF
#!/usr/bin/env Rscript
if (!require("BiocManager", quietly = TRUE))
  install.packages("BiocManager")
BiocManager::install(version = "3.15")
EOF

RUN --mount=type=cache,target=/var/cache/renv,sharing=locked \
<<EOF
#!/usr/bin/env Rscript
source("/usr/local/lib/R/etc/RProfile.site")
BiocManager::install(c(
    "DESeq2",
    "DEGreport",
    "ashr",

    "rjson",

    "purrr",
    "vctrs",
    "dplyr",
    "tibble",
    "readr",
    "readxl",

    "ggplot2",
    "ggrepel",
    "EnhancedVolcano",
    "heatmaply",
    "RColorBrewer",
    "plotly"
  ), update=FALSE)
EOF


RUN --mount=type=cache,target=/var/cache/renv,sharing=locked \
<<EOF
#!/usr/bin/env Rscript
source("/usr/local/lib/R/etc/RProfile.site")
BiocManager::install(c(
    "stringr",
    "data.table"
  ), update=FALSE)
EOF

# >>>
# Rest
# >>>

RUN pip install -U lytekit lytekitplugins-pods dataclasses_json
RUN pip install openpyxl defusedxml requests

RUN pip install pytest

COPY wf /root/wf
COPY test.py /root
WORKDIR /root

COPY ./r_scripts ./r_scripts
COPY ./template.html ./template.html

COPY client_secret.txt /root/client_secret.txt

COPY --from=flytectl /artifacts/flytectl /bin/flytectl

ARG tag
ENV FLYTE_INTERNAL_IMAGE $tag
