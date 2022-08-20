FROM 812206152185.dkr.ecr.us-west-2.amazonaws.com/latch-base:6839-main

SHELL ["/usr/bin/env", "bash", "-c"]

# Generic installation dependencies
# wget - obvious
# software-properties-common - `add-apt-repository`
# dirmngr - GPG key manager, loads from `/etc/apt/trusted.gpg.d/`
RUN apt-get update --yes &&\
    apt-get install --yes --no-install-recommends wget software-properties-common dirmngr

RUN apt-get update &&\
    apt-get install --yes --no-install-recommends pandoc

#
# R
#

# >>> Install R
# https://cloud.r-project.org/bin/linux/debian/
# https://github.com/rocker-org/rocker-versioned2/blob/f3325b2cf88d8899ddcb2f0945aa9f87ad150cd7/scripts/install_R_ppa.sh
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-key '95C0FAF38DB3CCAD0C080A7BDC78B2DDEABC47B7'
RUN debian_codename=$(lsb_release --codename --short) &&\
    add-apt-repository "deb https://cloud.r-project.org/bin/linux/debian ${debian_codename}-cran40/"

RUN apt-get update &&\
     apt-get install --yes r-base r-base-dev locales &&\
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
RUN apt-get update &&\
    apt install --yes libcurl4-openssl-dev libxml2-dev libssl-dev

# Build lasso2 (DEGReport depen) from source bc no longer on CRAN
RUN wget https://cran.r-project.org/src/contrib/Archive/lasso2/lasso2_1.2-22.tar.gz &&\
    tar -xzvf lasso2_1.2-22.tar.gz
COPY scripts/install_pkgs.R /tmp/install_pkgs.R
RUN /tmp/install_pkgs.R

RUN pip install openpyxl defusedxml requests
RUN pip install pytest

COPY ./r_scripts ./r_scripts
COPY ./template.html ./template.html

# >>>
# Rest
# >>>

RUN pip install latch==1.14.1
COPY wf /root/wf

ARG tag
ENV FLYTE_INTERNAL_IMAGE $tag
WORKDIR /root
