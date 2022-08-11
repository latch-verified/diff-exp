FROM 812206152185.dkr.ecr.us-west-2.amazonaws.com/latch-base:6839-main

SHELL ["/usr/bin/env", "bash", "-c"]

# Generic installation dependencies
# wget - obvious
# software-properties-common - `add-apt-repository`
# dirmngr - GPG key manager, loads from `/etc/apt/trusted.gpg.d/`
RUN set -o errexit &&\
    apt-get update &&\
    apt-get install --yes --no-install-recommends \
    wget \
    software-properties-common \
    dirmngr

RUN set -o errexit &&\
    apt-get update &&\
    apt-get install --yes --no-install-recommends \
      pandoc

#
# R
#

# >>> Install R
# https://cloud.r-project.org/bin/linux/debian/
# https://github.com/rocker-org/rocker-versioned2/blob/f3325b2cf88d8899ddcb2f0945aa9f87ad150cd7/scripts/install_R_ppa.sh
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-key '95C0FAF38DB3CCAD0C080A7BDC78B2DDEABC47B7' &&\
    debian_codename=$(lsb_release --codename --short) &&\
    add-apt-repository "deb https://cloud.r-project.org/bin/linux/debian ${debian_codename}-cran40/"

RUN  set -o errexit &&\
     apt-get update &&\
     apt-get install --yes \
       r-base \
       r-base-dev \
       locales &&\
     apt-mark hold r-base r-base-dev

RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen &&\
    locale-gen en_US.utf8 &&\
    /usr/sbin/update-locale LANG="en_US.UTF-8"

# Configure binary package caches
RUN mkdir -p /usr/local/lib/R/etc/RProfile &&\ 
    echo 'options(HTTPUserAgent = sprintf("R/%s R (%s)", getRversion(), paste(getRversion(), R.version["platform"], R.version["arch"], R.version["os"])))' > /usr/local/lib/R/etc/RProfile.site

# Install renv
ENV RENV_PATHS_CACHE="/var/cache/renv"
COPY scripts/install_renv.R /tmp/install_renv.R
RUN /tmp/install_renv.R


# >>> R packages
RUN set -o errexit &&\
    apt-get update &&\
    apt install --yes \
      libcurl4-openssl-dev \
      libxml2-dev \
      libssl-dev

COPY scripts/install_pkgs.R /tmp/install_pkgs.R
RUN /tmp/install_pkgs.R

# >>>
# Rest
# >>>

RUN pip install -U lytekit lytekitplugins-pods dataclasses_json
RUN pip install openpyxl defusedxml requests
RUN pip install pytest

COPY wf /root/wf
COPY test.py /root
COPY ./r_scripts ./r_scripts
COPY ./template.html ./template.html

RUN pip install -U latch
ARG tag
ENV FLYTE_INTERNAL_IMAGE $tag
WORKDIR /root
