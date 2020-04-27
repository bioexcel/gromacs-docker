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

FROM nvidia/cuda:10.2-runtime-ubuntu18.04

# install required packages
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    libblas \
    libgomp1 \
    liblapack \
    openmpi-bin \
    openmpi-common \
    python3 \
  && rm -rf /var/lib/apt/lists/*

# Add the fftw3 libraries
COPY --from=gromacs/fftw /usr/local/lib /usr/local

# Add the GROMACS configurations
COPY --from=gromacs/gmx-configurations:gmx-2020.1-cuda-10.2-SSE2     /gromacs /gromacs
COPY --from=gromacs/gmx-configurations:gmx-2020.1-cuda-10.2-AVX_256  /gromacs /gromacs
COPY --from=gromacs/gmx-configurations:gmx-2020.1-cuda-10.2-AVX2_256 /gromacs /gromacs
COPY --from=gromacs/gmx-configurations:gmx-2020.1-cuda-10.2-AVX_512  /gromacs /gromacs

# Add architecture-detection script
COPY gmx-chooser /gromacs/bin/gmx
RUN chmod +x /gromacs/bin/gmx

ENV PATH=$PATH:/gromacs/bin

#
# Enable the entrypoint to use the dockerfile as a GROMACS binary
#ENTRYPOINT [ "/gromacs/bin/gmx" ]
