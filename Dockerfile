###############################################################################
# Ubuntu 16.04, CUDA 9.0, OpenMPI, and GROMACS.
#
# Requirements:
# * gromacs directory in build directory with source for GROMACS.
#
# Build with:
# sudo nvidia-docker build -t gromacs . \
#   --build-arg GROMACS_VERSION=gromacs_version \
#   --build-arg JOBS=16
#
# The build args are optional. To get the versions consistent with GROMACS
# in general, use e.g. 2018 for the main realease, and 2018.4 for the
# fourth patch release.
#
# Run with:
# sudo nvidia-docker run -it gromacs
#
# Test with:
# sudo nvidia-docker run -it -v /path/to/gromacs/scripts:/scripts gromacs \
#   /scripts/validate_gromacs.sh
###############################################################################

###############################################################################
# Build stage
###############################################################################
FROM nvidia/cuda:9.0-devel-ubuntu16.04 as builder

# Update according to http://manual.gromacs.org/documentation/
ARG GROMACS_VERSION=2020.1
ARG GROMACS_MD5=1c1b5c0f904d4eac7e3515bc01ce3781

ARG FFTW_VERSION=3.3.8
ARG FFTW_MD5=8aac833c943d8e90d51b697b27d4384d

# number of make jobs during compile
ARG JOBS=16


# default loop value
ARG GROMACS_ARCH='SSE2 AVX_256 AVX2_256 AVX_512'


# install required packages
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    cmake \
    curl \
    libopenmpi-dev \
    openmpi-bin \
    openmpi-common \
    python \
  && rm -rf /var/lib/apt/lists/*
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib/openmpi/lib

# Download sources
RUN mkdir -p /gromacs /gromacs-src
WORKDIR /gromacs-src
RUN curl -o gromacs.tar.gz http://ftp.gromacs.org/pub/gromacs/gromacs-${GROMACS_VERSION}.tar.gz &&\ 
    echo "${GROMACS_MD5}  gromacs.tar.gz" > gromacs.tar.gz.md5 &&\
    md5sum -c gromacs.tar.gz.md5 &&\
    tar zxf gromacs.tar.gz &&\
    mv gromacs-${GROMACS_VERSION}/* .

# Install fftw with more optimizations than the default packages
# It is not critical to run the tests here, since our experience is that the
# Gromacs unit tests will catch fftw build errors too.
RUN curl -o fftw.tar.gz http://www.fftw.org/fftw-${FFTW_VERSION}.tar.gz \
  && echo "${FFTW_MD5}  fftw.tar.gz" > fftw.tar.gz.md5 \
  && md5sum -c fftw.tar.gz.md5 \
  && tar -xzvf fftw.tar.gz && cd fftw-${FFTW_VERSION} \
  && ./configure --disable-double --enable-float --enable-sse2 --enable-avx --enable-avx2 --enable-avx512 --enable-shared --disable-static \
  && make -j ${JOBS} \
  && make install

# build GROMACS and run unit tests
# To cater to different architectures, we build for all of them
# and install in different bin/lib directories.

# You can change the architecture list here to add more SIMD types,
# but make sure to always include SSE2 as a fall-back.
RUN for ARCH in ${GROMACS_ARCH}; do \
     mkdir -p /gromacs-build.${ARCH} && cd /gromacs-build.${ARCH} \
  && CC=gcc CXX=g++ cmake /gromacs-src \
    -DGMX_OPENMP=ON \
    -DGMX_GPU=ON \
    -DGMX_MPI=OFF \
    -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda \
    -DCMAKE_INSTALL_PREFIX=/gromacs \
    -DREGRESSIONTEST_DOWNLOAD=ON \
#    -DMPIEXEC_PREFLAGS=--allow-run-as-root \
    -DGMX_SIMD=${ARCH} \
    -DCMAKE_INSTALL_BINDIR=bin.${ARCH} \
    -DCMAKE_INSTALL_LIBDIR=lib.${ARCH} \
  && make -j ${JOBS} \
  && make install; done

# Run tests (optional)
# We avoid running tests for AVX_512, since that hardware might not be available
#RUN for ARCH in SSE2 AVX_256 AVX2_256; do \
#    cd /gromacs-build.${ARCH} && make -j ${JOBS} check; done

#
# Build the program to identify number of AVX512 FMA units
# This will only be executed on AVX-512-capable hosts. If there
# are dual AVX-512 FMA units, it will be faster to use AVX-512 SIMD, but if
# there's only a single one we prefer AVX2_256 SIMD instead.
#
RUN if [ -d "/gromacs-build.AVX_512" ]; \
    then cd /gromacs-build.AVX_512 \
  && g++ -O3 -mavx512f -std=c++11 \
    -DGMX_IDENTIFY_AVX512_FMA_UNITS_STANDALONE=1 \
    -DGMX_X86_GCC_INLINE_ASM=1 \
    -DSIMD_AVX_512_CXX_SUPPORTED=1 \
    -o /gromacs/bin.AVX_512/identifyavx512fmaunits \
    /gromacs-src/src/gromacs/hardware/identifyavx512fmaunits.cpp; \
    fi;

# 
# Add architecture-detection script
COPY gmx-chooser /gromacs/bin/gmx
RUN chmod +x /gromacs/bin/gmx

###############################################################################
# Final stage
###############################################################################
FROM nvidia/cuda:9.0-runtime-ubuntu16.04

# install required packages
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    libgomp1 \
    libopenmpi-dev \
    openmpi-bin \
    openmpi-common \
    python \
  && rm -rf /var/lib/apt/lists/*

# copy fftw libraries
COPY --from=builder /usr/local/lib /usr/local/lib

# copy gromacs install
COPY --from=builder /gromacs /gromacs
ENV PATH=$PATH:/gromacs/bin

# setup labels
LABEL com.nvidia.gromacs.version="${GROMACS_VERSION}"

# NVIDIA-specific stuff?
#WORKDIR /workspace
#COPY examples examples 

#
# Enable the entrypoint to use the dockerfile as a GROMACS binary
#ENTRYPOINT [ "/gromacs/bin/gmx" ]
