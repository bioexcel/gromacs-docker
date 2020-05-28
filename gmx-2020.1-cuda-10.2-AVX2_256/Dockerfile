FROM nvidia/cuda:10.2-devel-ubuntu18.04

RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        git \
        gnupg \
        libblas-dev \
        libhwloc-dev \
        liblapack-dev \
        libx11-dev \
        ninja-build \
        wget && \
    rm -rf /var/lib/apt/lists/*

# GNU compiler
RUN apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends software-properties-common && \
    apt-add-repository ppa:ubuntu-toolchain-r/test -y && \
    apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        g++-8 \
        gcc-8 && \
    rm -rf /var/lib/apt/lists/*
RUN update-alternatives --install /usr/bin/g++ g++ $(which g++-8) 30 && \
    update-alternatives --install /usr/bin/gcc gcc $(which gcc-8) 30 && \
    update-alternatives --install /usr/bin/gcov gcov $(which gcov-8) 30

RUN wget -qO - https://apt.kitware.com/keys/kitware-archive-latest.asc | apt-key add - && \
    echo "deb [arch=amd64] https://apt.kitware.com/ubuntu/ bionic main" >> /etc/apt/sources.list.d/hpccm.list && \
    apt-get update -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        cmake && \
    rm -rf /var/lib/apt/lists/*

COPY --from=gromacs/fftw /usr/local/lib \
    /usr/local/include \
    /usr/local/

# ftp://ftp.gromacs.org/pub/gromacs/gromacs-2020.1.tar.gz

RUN mkdir -p /var/tmp && wget -q -nc --no-check-certificate -P /var/tmp ftp://ftp.gromacs.org/pub/gromacs/gromacs-2020.1.tar.gz && \
    mkdir -p /var/tmp && tar -x -f /var/tmp/gromacs-2020.1.tar.gz -C /var/tmp -z && \
    cd /var/tmp/gromacs-2020.1 && \
    mkdir -p build && \
    cmake -S . -B build -D CMAKE_BUILD_TYPE=Release -D CUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda -D GMX_SIMD=AVX2_256 -D GMX_FFT_LIBRARY=fftw3 -D GMX_EXTERNAL_BLAS=ON -D GMX_EXTERNAL_LAPACK=ON -D GMX_GPU=ON -D GMX_MPI=OFF -D CMAKE_INSTALL_PREFIX=/gromacs/bin.AVX2_256 -D GMX_OPENMP=ON -G Ninja && \
    cmake -S . -B build && \
    cmake --build build --target all -- -j2 && \
    cd /var/tmp/gromacs-2020.1 && \
    cmake --install build && \
    rm -rf /var/tmp/gromacs-2020.1 /var/tmp/gromacs-2020.1.tar.gz


