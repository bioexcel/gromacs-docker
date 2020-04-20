###############################################################################
# Ubuntu 18.04, CUDA 10.2, OpenMPI, and GROMACS.
#
# This container is built automatically on Docker Hub, but can be built
# manually with:
# docker build -t gromacs .
#
# Run with:
# sudo nvidia-docker run -it gromacs
###############################################################################

###############################################################################
# Build stage
###############################################################################
FROM nvidia/cuda:10.2-devel-ubuntu18.04 as builder

# install required packages
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    libopenmpi-dev \
    openmpi-bin \
    openmpi-common \
    python \
  && rm -rf /var/lib/apt/lists/*
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/lib/openmpi/lib

COPY --from=gromacs/gmx-configurations:gmx-2020.1-cuda-10.2-SSE2 /gromacs /gromacs

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
FROM nvidia/cuda:10.2-runtime-ubuntu18.04

# install required packages
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    libgomp1 \
    libopenmpi-dev \
    openmpi-bin \
    openmpi-common \
    python \
  && rm -rf /var/lib/apt/lists/*

# copy gromacs install
COPY --from=builder /gromacs /gromacs
ENV PATH=$PATH:/gromacs/bin

#
# Enable the entrypoint to use the dockerfile as a GROMACS binary
#ENTRYPOINT [ "/gromacs/bin/gmx" ]
