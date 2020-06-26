###############################################################################
# Build of FFTW suitable for single-precision GROMACS
#
# Build with:
# sudo docker build -t fftw .
#
# This container provides pre-build FFTW libraries useful for building
# GROMACS with. It is used in the gromacs-docker repo as part of a builder
# pattern for efficient builds and minimal resulting containers.
#
# Please open merge requests that update the FFTW_VERSION and FFTW_MD5
# when updates to FFTW are released.
###############################################################################

FROM ubuntu:18.04

ARG FFTW_VERSION=3.3.8
ARG FFTW_MD5=8aac833c943d8e90d51b697b27d4384d

# install required packages
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    software-properties-common \
  && add-apt-repository ppa:ubuntu-toolchain-r/test \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    gcc-9 \
  && rm -rf /var/lib/apt/lists/*

# Install fftw with more optimizations than the default packages.  It
# is not critical to run the tests here, since the GROMACS tests will
# catch fftw build errors too.

RUN curl -o fftw.tar.gz http://www.fftw.org/fftw-${FFTW_VERSION}.tar.gz \
  && echo "${FFTW_MD5}  fftw.tar.gz" > fftw.tar.gz.md5 \
  && md5sum -c fftw.tar.gz.md5 \
  && tar -xzvf fftw.tar.gz && cd fftw-${FFTW_VERSION} \
  && ./configure --disable-double --enable-float --enable-sse2 --enable-avx --enable-avx2 --enable-avx512 --disable-static --enable-shared \
  && make \
  && make install \
  && rm -rf fftw.tar.gz fftw.tar.gz.md5 fftw-${FFTW_VERSION}
