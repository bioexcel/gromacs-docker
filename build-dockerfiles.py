#!/usr/bin/env python

"""Generates a set of docker images each containing a single build configuration
of GROMACS. These are combined via the Docker builder pattern into the
multi-configuration container on Docker Hub gromacs/gromacs. It examines the
environment at run time and dispatches to the correct build configuration.

The images are prepared according to a selection of build
configuration targets that cover a broad scope of different possible
run-time environmeents. Each combination is described as an entry in
the build_configs dictionary, with the script analysing the logic and
adding build stages as needed.

Based on the example script provided by the NVidia HPCCM repository
from https://github.com/NVIDIA/hpc-container-maker and ideas from the
similar script used within the main GROMACS repository for building
containers used for CI testing.

Authors:
    * Mark Abraham <mark.j.abraham@gmail.com>

Usage::

    $ python3 build-dockerfiles.py --help
    $ python3 build-dockerfiles.py --format docker > Dockerfile && docker build .
    $ python3 build-dockerfiles.py | docker build -

"""

import argparse
import collections
import typing
from distutils.version import StrictVersion

import hpccm
import hpccm.config
from hpccm.building_blocks.base import bb_base

try:
    import utility
except ImportError:
    raise RuntimeError(
        'This module assumes availability of supporting modules in the same directory. Add the directory to '
        'PYTHONPATH or invoke Python from within the module directory so module location can be resolved.')

# Basic packages for all final images.
_common_packages = ['build-essential',
                    'ca-certificates',
                    'git',
                    'gnupg',
                    'libhwloc-dev',
                    'libblas-dev',
                    'liblapack-dev',
                    'libx11-dev',
                    'ninja-build',
                    'wget']

# Parse command line arguments
parser = argparse.ArgumentParser(description='GROMACS Dockerfile creation script', parents=[utility.parser])

parser.add_argument('--format', type=str, default='docker',
                    choices=['docker', 'singularity'],
                    help='Container specification format (default: docker)')
parser.add_argument('--version', type=str, default='2020.2',
                    choices=['2020.1', '2020.2'],
                    help='Version of GROMACS to build')
parser.add_argument('--simd', type=str, default='auto',
                    choices=['AUTO', 'SSE2', 'AVX_256', 'AVX2_256', 'AVX_512'],
                    help='SIMD flavour of GROMACS to build')

def base_image_tag(args) -> str:
    # Check if we use CUDA images or plain linux images
    if args.cuda is not None:
        cuda_version_tag = 'nvidia/cuda:' + args.cuda + '-devel'
        if args.centos is not None:
            cuda_version_tag += '-centos' + args.centos
        elif args.ubuntu is not None:
            cuda_version_tag += '-ubuntu' + args.ubuntu
        else:
            raise RuntimeError('Logic error: no Linux distribution selected.')

        base_image_tag = cuda_version_tag
    else:
        if args.centos is not None:
            base_image_tag = 'centos:centos' + args.centos
        elif args.ubuntu is not None:
            base_image_tag = 'ubuntu:' + args.ubuntu
        else:
            raise RuntimeError('Logic error: no Linux distribution selected.')
    return base_image_tag


def get_compiler(args):
    compiler = hpccm.building_blocks.gnu(extra_repository=True,
                                         version=args.gcc,
                                         fortran=False)
    return compiler

def get_mpi(args, compiler):
    # If needed, add MPI to the image
    if args.mpi is not None:
        if args.mpi == 'openmpi':
            use_cuda = False
            if args.cuda is not None:
                use_cuda = True

            if hasattr(compiler, 'toolchain'):
                return hpccm.building_blocks.openmpi(toolchain=compiler.toolchain, cuda=use_cuda, infiniband=False)
            else:
                raise RuntimeError('compiler is not an HPCCM compiler building block!')

        elif args.mpi == 'impi':
            raise RuntimeError('Intel MPI recipe not implemented yet.')
        else:
            raise RuntimeError('Requested unknown MPI implementation.')
    else:
        return None

def get_cmake(args):
    return hpccm.building_blocks.packages(
        apt_keys=['https://apt.kitware.com/keys/kitware-archive-latest.asc'],
        apt_repositories=['deb [arch=amd64] https://apt.kitware.com/ubuntu/ bionic main'],
        ospackages=['cmake']
        )

def build_gmx(args):
    # Install the FFTW dependency from Docker Hub
    gmx = [hpccm.primitives.copy(src=['/usr/local/lib', '/usr/local/include'], dest='/usr/local', _from='gromacs/fftw')]
    # Build and install GROMACS
    source_dir = '.'
    build_dir = 'build'
    install_dir = f'/gromacs/bin.{args.simd}'
    cmake_command = (
        f'cmake -S {source_dir} -B {build_dir} '
        f'-D CMAKE_BUILD_TYPE=Release '
        f'-D CUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda '
        f'-D GMX_SIMD={args.simd} '
        f'-D GMX_FFT_LIBRARY=fftw3 '
        f'-D GMX_EXTERNAL_BLAS=ON '
        f'-D GMX_EXTERNAL_LAPACK=ON '
        f'-D GMX_GPU=ON '
        f'-D GMX_MPI=OFF '
        f'-D CMAKE_INSTALL_PREFIX={install_dir} '
        #f'-D MPIEXEC_PREFLAGS=--allow-run-as-root '
        f'-D GMX_OPENMP=ON '
        f'-G Ninja' )
    build_command = [f'mkdir -p {build_dir}',
                     cmake_command,
                     # This repeat run of cmake works around a bug
                     # where the second run of cmake updates config.h
                     # in a way that triggers a re-build of many
                     # source files.
                     f'cmake -S {source_dir} -B {build_dir}',
                     f'cmake --build {build_dir} --target all -- -j2']
    install_command = [f'cmake --install {build_dir}']
    # TODO add some basic testing to run on Docker Hub
    if args.simd == "AVX_512":
        # Build the program to identify number of AVX-512 FMA units on
        # an execution host capable of AVX-512 instructions. The
        # caller is responsible for determing whether the host is
        # AVX-512 capable, or accepting that this program will fail
        # when executing an illegal instruction. The reason for this
        # program is that if there are dual AVX-512 FMA units, it will
        # be faster to use AVX-512 SIMD, but if there's only a single
        # FMA unit, GROMACS runs faster with AVX2_256 SIMD. This
        # cannot be detected from CPUID bits.
        identify_avx_512_fma_units_command = (
            f'g++ -O3 -mavx512f -std=c++11 '
            f'-D GMX_IDENTIFY_AVX512_FMA_UNITS_STANDALONE=1 '
            f'-D GMX_X86_GCC_INLINE_ASM=1 '
            f'-D SIMD_AVX_512_CXX_SUPPORTED=1 '
            f'{source_dir}/src/gromacs/hardware/identifyavx512fmaunits.cpp '

            f'-o {build_dir}/bin/identifyavx512fmaunits' )
        build_command.append(identify_avx_512_fma_units_command)
        install_command.append(f'cp {build_dir}/bin/identifyavx512fmaunits {install_dir}/bin')
    gmx += hpccm.building_blocks.generic_build(
        build=build_command,
        install=install_command,
        url=f'ftp://ftp.gromacs.org/pub/gromacs/gromacs-{args.version}.tar.gz',)
    return gmx

def build_stages(args) -> typing.Iterable[hpccm.Stage]:
    """Define and sequence the stages for the recipe corresponding to *args*."""

    # A Dockerfile or Singularity recipe can have multiple build stages.
    # The main build stage can copy files from previous stages, though only
    # the last stage is included in the tagged output image. This means that
    # large or expensive sets of build instructions can be isolated in
    # local/temporary images, but all of the stages need to be output by this
    # script, and need to occur in the correct order, so we create a sequence
    # object early in this function.
    stages = collections.OrderedDict()

    # Building blocks are chunks of container-builder instructions that can be
    # copied to any build stage with the addition operator.
    building_blocks = collections.OrderedDict()

    os_packages = _common_packages
    building_blocks['ospackages'] = hpccm.building_blocks.packages(ospackages=os_packages)
    
    # These are the most expensive and most reusable layers, so we put them first.
    building_blocks['compiler'] = get_compiler(args)
    building_blocks['mpi'] = get_mpi(args, building_blocks['compiler'])
    building_blocks['cmake'] = get_cmake(args)
#    building_blocks['configure_gmx'] = configure_gmx(args, building_blocks['compiler'])
    building_blocks['build_gmx'] = build_gmx(args)

    # Create the stage from which the targeted image will be tagged.
    stages['main'] = hpccm.Stage()

    stages['main'] += hpccm.primitives.baseimage(image=base_image_tag(args))
    for bb in building_blocks.values():
        if bb is not None:
            stages['main'] += bb

    # Note that the list of stages should be sorted in dependency order.
    for build_stage in stages.values():
        if build_stage is not None:
            yield build_stage


if __name__ == '__main__':
    args = parser.parse_args()

    # Set container specification output format
    hpccm.config.set_container_format(args.format)

    container_recipe = build_stages(args)

    # Output container specification
    for stage in container_recipe:
        print(stage)
