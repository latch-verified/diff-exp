# syntax = docker/dockerfile:1.4.1
FROM 812206152185.dkr.ecr.us-west-2.amazonaws.com/latch-base:9c8f-main

SHELL ["/usr/bin/env", "bash", "-c"]

# Generic installation dependencies
# wget - obvious
# software-properties-common - `add-apt-repository`
# dirmngr - GPG key manager, loads from `/etc/apt/trusted.gpg.d/`
RUN apt-get update --yes &&\
    apt-get install --yes --no-install-recommends wget software-properties-common dirmngr

RUN apt-get update &&\
    apt-get install --yes --no-install-recommends pandoc

RUN apt-get update &&\
    apt-get install --yes libcurl4-openssl-dev libxml2-dev libssl-dev libgsl-dev

#
# R
#

# >>> Install R
run wget https://github.com/r-lib/rig/releases/download/latest/rig-linux-latest.tar.gz
run tar \
    --extract \
    --gunzip \
    --file rig-linux-latest.tar.gz \
    --directory /usr/local/
run rm rig-linux-latest.tar.gz
run rig add release

# >>> R packages
env R_PKG_SYSREQS2="true"
copy scripts/install_pkgs.R /tmp/install_pkgs.R
run /tmp/install_pkgs.R

run wget https://cran.r-project.org/src/contrib/Archive/lasso2/lasso2_1.2-22.tar.gz && \
    tar -xzvf lasso2_1.2-22.tar.gz
run R -e 'install.packages("/root/lasso2", repos = NULL, type = "source", update = FALSE)'

RUN pip install openpyxl defusedxml requests
RUN pip install pytest

# >>>
# Rest
# >>>

RUN pip install latch==2.32.8

COPY ./r_scripts ./r_scripts
COPY ./template.html ./template.html
COPY wf /root/wf

ARG tag
ENV FLYTE_INTERNAL_IMAGE $tag
WORKDIR /root
