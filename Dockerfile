FROM ubuntu:16.04

RUN apt-get update \
    && apt-get install -y \
        libopenmpi-dev openmpi-bin mpich git pkg-config gcc-5 gcc-4.8 \
        nano autoconf wget unzip sudo \
    && rm -rf /var/lib/apt/lists/*

ARG IO500_DOWNLOAD_URL=https://github.com/johngarbutt/io-500-dev/archive/master.zip

RUN useradd -ms /bin/bash io500
USER io500

RUN set -x \
    && cd /home/io500 \
    && wget -O io500.zip "$IO500_DOWNLOAD_URL" \
    && unzip io500.zip \
    && rm io500.zip \
    && mkdir io-500-dev \
    && mv io-500-dev-master/* io-500-dev \
    && rm -rf io-500-dev-master

RUN set -x \
    && cd /home/io500/io-500-dev \
    && ls . \
    && ./utilities/prepare.sh

WORKDIR /home/io500/io-500-dev

VOLUME /home/io500/io-500-dev/datafiles
VOLUME /home/io500/io-500-dev/results

USER root
ENTRYPOINT ["/home/io500/io-500-dev/entrypoint.sh"]
