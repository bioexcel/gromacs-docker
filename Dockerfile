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
    libgomp1 \
    liblapack3 \
    openmpi-bin \
    openmpi-common \
    python3 \
  && rm -rf /var/lib/apt/lists/*

## Add the fftw3 libraries
COPY --from=gromacs/gromacs-docker:fftw-3.3.8 /usr/local/lib /usr/local/lib

# Add the GROMACS configurations

#COPY --from=gromacs/gromacs-docker:gmx-2020.2-cuda-10.2-SSE2     /gromacs /gromacs
#COPY --from=gromacs/gromacs-docker:gmx-2020.2-cuda-10.2-AVX_256  /gromacs /gromacs
#COPY --from=gromacs/gromacs-docker:gmx-2020.2-cuda-10.2-AVX2_256 /gromacs /gromacs
#COPY --from=gromacs/gromacs-docker:gmx-2020.2-cuda-10.2-AVX_512  /gromacs /gromacs

# Add architecture-detection script
COPY gmx-chooser /gromacs/bin/gmx
RUN chmod +x /gromacs/bin/gmx

ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
ENV PATH=$PATH:/gromacs/bin

#
# Enable the entrypoint to use the dockerfile as a GROMACS binary
#ENTRYPOINT [ "/gromacs/bin/gmx" ]
