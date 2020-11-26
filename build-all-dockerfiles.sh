#!/bin/bash

gromacs_version=2020.2
cuda_version=10.2
simd_types=(SSE2 AVX_256 AVX2_256 AVX_512)
for simd in ${simd_types[@]}
do
    tag=gmx-$gromacs_version-cuda-$cuda_version-$simd
    mkdir -p $tag
    python3 build-dockerfiles.py --simd $simd --gcc 8 --cuda $cuda_version --version $gromacs_version --format docker > $tag/Dockerfile
done
