#!/bin/bash

version=2020.2

for simd in SSE2 AVX_256 AVX2_256 AVX_512
do
    tag=gmx-$version-cuda-10.2-$simd
    mkdir -p $tag
    python3 build-dockerfiles.py --simd $simd --gcc 8 --cuda 10.2 --version $version --format docker > $tag/Dockerfile
done
