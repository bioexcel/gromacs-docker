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
    openssh-client \
    wget \
  && rm -rf /var/lib/apt/lists/*

## Add the fftw3 libraries
COPY --from=gromacs/gromacs-docker:fftw-3.3.8 /usr/local/lib /usr/local/lib

# Copy compiled dependencies


# Add the GROMACS configurations

#COPY --from=gromacs/gromacs-docker:gmx-2020.2-cuda-10.2-SSE2     /gromacs /gromacs
#COPY --from=gromacs/gromacs-docker:gmx-2020.2-cuda-10.2-AVX_256  /gromacs /gromacs
#COPY --from=gromacs/gromacs-docker:gmx-2020.2-cuda-10.2-AVX2_256 /gromacs /gromacs
#COPY --from=gromacs/gromacs-docker:gmx-2020.2-cuda-10.2-AVX_512  /gromacs /gromacs

# Add architecture-detection script
COPY gmx-chooser /gromacs/bin/gmx
RUN chmod +x /gromacs/bin/gmx

# "docker run --gpu 1" will bind /usr/lib/x86_64-linux-gnu/libcuda.so.1 found by
# x86_64-linux-gnu.conf, however for non-CUDA execution we'll put this
# as a fallback to avoid gmx warning messages about missing libcuda.so.1
RUN echo /usr/local/cuda/compat > /etc/ld.so.conf.d/zz-cuda-compat.conf && \
    ldconfig

# Environment variables
ENV PATH=$PATH:/gromacs/bin

#
# Enable the entrypoint to use the dockerfile as a GROMACS binary
#ENTRYPOINT [ "/gromacs/bin/gmx" ]
