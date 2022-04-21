# GROMACS

[![bioexcel/gromacs](https://img.shields.io/badge/docker-gromacs%2Fgromacs-1488C6.svg?logo=docker)](https://hub.docker.com/r/gromacs/gromacs/ "gromacs/gromacs")
[![bioexcel/gromacs](https://images.microbadger.com/badges/image/gromacs/gromacs.svg)](https://microbadger.com/images/gromacs/gromacs)
[![NVIDIA CUDA optimized](https://img.shields.io/badge/CUDA-optimized-76B900.svg?logo=nvidia)](https://www.nvidia.com/en-gb/data-center/gpu-accelerated-applications/gromacs/)
[![GNU GPL 2.1+](https://img.shields.io/badge/license-LGPL2.1+-A42E2B.svg?logo=gnu)](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.en.html)
[![Docker image releases](https://img.shields.io/github/release/bioexcel/gromacs-docker.svg)](https://github.com/bioexcel/gromacs-docker/releases)


[GROMACS](http://www.gromacs.org/) is a versatile package to perform molecular dynamics, i.e. simulate the Newtonian equations of motion for systems with hundreds to millions of particles.

It is primarily designed for biochemical molecules like proteins, lipids and nucleic acids that have a lot of complicated bonded interactions, but since GROMACS is extremely fast at calculating the nonbonded interactions (that usually dominate simulations) many groups are also using it for research on non-biological systems, e.g. polymers.

This is a Docker image of GROMACS, which - if used with [nvidia-docker](https://github.com/NVIDIA/nvidia-docker) - can provide hardware acceleration using NVIDIA GPUs.

## Tags

Docker image tags correspond to the official [Gromacs releases](http://manual.gromacs.org/documentation/). Note that the tags without a minor version number (e.g. `2019`) are not updated for new minor versions (e.g. `2019.1`), as `2019` and `2019.1` are distinct GROMACS versions (`2019` ~= `2019.0`).

Feel free to raise a [pull request](https://github.com/bioexcel/gromacs-docker/pulls) to add a new release by updating `GROMACS_VERSION` and `GROMACS_MD5`. 


## Running

Docker requires [binding](https://docs.docker.com/storage/bind-mounts/) of any directory that the container should have access to. The flag `-it` is also recommended for any interactive steps. All GROMACS commands are executed as `gmx MODULE`,  each module provides their own help:

    docker run gromacs/gromacs gmx help commands
    docker run gromacs/gromacs gmx help pdb2gmx 

The below highlights this using an example of using `pdb2gmx` from the tutorial [KALP15 in DPPC](http://www.mdtutorials.com/gmx/membrane_protein/01_pdb2gmx.html):

    mkdir $HOME/data ; cd $HOME/data
    wget http://www.mdtutorials.com/gmx/membrane_protein/Files/KALP-15_princ.pdb
    docker run -v $HOME/data:/data -w /data -it gromacs/gromacs gmx pdb2gmx -f KALP-15_princ.pdb -o KALP-15_processed.gro -ignh -ter -water spc

If you get a permissions error when trying to run this command it is likely that SELINUX is blocking it and the permissions need to be set by adding `:Z` to the end of the volume bind as so:

    mkdir $HOME/data ; cd $HOME/data
    wget http://www.mdtutorials.com/gmx/membrane_protein/Files/KALP-15_princ.pdb
    docker run -v $HOME/data:/data:Z -w /data -it gromacs/gromacs gmx pdb2gmx -f KALP-15_princ.pdb -o KALP-15_processed.gro -ignh -ter -water spc


It is beyond the scope of this README file to document GROMACS usage. For further information see:

* http://manual.gromacs.org/documentation/
* http://www.mdtutorials.com/gmx/


### Hardware-acceleration

The command `gmx` in this container image will attempt to [detect](https://github.com/bioexcel/gromacs-docker/blob/dev/gmx-chooser) your CPU's AVX/SSE flags to use the corresponding optimized `gmx` binary.

If you have an NVIDIA GPU, some GROMACS modules (in particular `mdrun`) can benefit hugely from hardware acceleration by using [nvidia-docker](https://github.com/NVIDIA/nvidia-docker) which takes care of mapping the GPU device files. Simply replace `docker` above with `nvidia-docker` in the commands above.

### Other distributions

A pre-compiled GROMACS distribution using OpenCL acceleration is available from [BioConda](https://anaconda.org/bioconda/gromacs).

The corresponding [BioContainers](https://quay.io/repository/biocontainers/gromacs?tab=tags) Docker image can be used instead of this image, but that will not be able to provide GPU acceleration without additional binding of OpenCL folders.

Debian/Ubuntu [include GROMACS](https://packages.ubuntu.com/search?keywords=gromacs) with variants for different hardware, but these may not be the latest version.

In many cases compiling GROMACS from [source code](http://manual.gromacs.org/current/download) for your particular OS/hardware will provide additional performance gains. See the [installation guide](http://manual.gromacs.org/current/install-guide/index.html) for details.

## License

GROMACS is free software, distributed under the [GNU Lesser General
Public License (LGPL) Version 2.1](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.en.html) or (at your option) any later version. See [COPYING](COPYING) for details.

This Docker image is based on the image [nvidia/cuda](https://hub.docker.com/r/nvidia/cuda) that includes the [CUDA](http://docs.nvidia.com/cuda) runtime by NVIDIA. By downloading these images, you agree to the terms of the [license agreements](http://docs.nvidia.com/cuda/eula/index.html) for the included NVIDIA software. 

Other open source dependencies include:

* [fftw](http://www.fftw.org/) [GPL 2.0 or later](https://github.com/FFTW/fftw3/blob/master/COPYING)
* [libgomp1](https://packages.ubuntu.com/xenial/libgomp1)
* [openmpi](https://packages.ubuntu.com/xenial/openmpi-bin)
* [python](https://packages.ubuntu.com/xenial/python/)

## Contribute

Contributions welcome! Please fork this repository and submit a pull request to the dev branch.

The source code for GROMACS is available from http://manual.gromacs.org/current/download and is maintained at https://github.com/gromacs/gromacs

### Building the containers

All of the containers are built by GitHub actions.  This is done in a three part process.

 - Build a container with optimised FFTW in.
 - Build containers with emacs optimised for each SIMD type and/or gromacs version
 - Build a container for each gromacs version that includes all containers built\
 in the previous step

This will require you to have an account on Dockerhub, and to have setup a PAT that you have then told Github about.  The main part that then needs changing is the dockerhub repository in the workflow file: `.github/workflow/main.yml`

### Bumping the version of gromacs, cuda or SIMD types

To change the version of gromacs or CUDA, you just need to change the variables in the workflow file: `.github/workflow/main.yml`

At the start of this file there is a list of parameters that can be changed such as GROMACS version, CUDA version and SIMD types.

To change the SIMD types you need to change the variable "simd_types". This should be a space separted list of SIMD types.  This will be used to create the workflow matrix to build each of the SIMD specifc containers.

### CI Workflow and how the container is built


`generate_specifications_file.py` will build all containers needed to create the final docker conatiner.  It is provided from `gromacs-hpccm-recipes-mult-stages`.

Firstly, `generate_specifications_file.py` takes many options. It is first called to generate an FFTW container that is optimised for all the SIMD types in `simd_types`.

Next, `generate_specifications_file.py` is called in a job matrix to build an optimised version of GROMACS for each SIMD type.  Each of these is then registered to DockerHub with the name `gmx-GROMACS_version-cuda-CUDA_version-SIMD_type`.

Finally, a new Docker container is created which copies the optimised GROMACS versions from the containers built into a single container and publishes this to DockerHub

## Contact us

Subscribe to the [GROMACS mailing list](http://www.gromacs.org/Support/Mailing_Lists/GMX-developers_List) for any questions.
