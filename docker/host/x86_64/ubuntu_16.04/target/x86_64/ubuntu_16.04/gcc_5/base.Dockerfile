# Dockerfile for libcudacxx_base:host_x86_64_ubuntu_16.04__target_x86_64_ubuntu_16.04__gcc_7

FROM ubuntu:16.04

MAINTAINER Bryce Adelstein Lelbach <blelbach@nvidia.com>

ARG LIBCUDACXX_SKIP_BASE_TESTS_BUILD
ARG LIBCUDACXX_COMPUTE_ARCHS

###############################################################################
# BUILD: The following is invoked when the image is built.

RUN apt-get -y update\
 && apt-get -y install g++-5 clang-5.0 python python-pip\
 && pip install lit\
 && mkdir -p /sw/gpgpu/libcudacxx/build\
 && mkdir -p /sw/gpgpu/libcudacxx/libcxx/build

# The distro doesn't have CMake 3.8 in its repositories, so we need to install
# it ourselves.
ADD https://github.com/Kitware/CMake/releases/download/v3.8.2/cmake-3.8.2-Linux-x86_64.sh /tmp/cmake.sh
RUN sh /tmp/cmake.sh --skip-license --prefix=/usr

# For debugging.
#RUN apt-get -y install gdb strace vim

# We use ADD here because it invalidates the cache for subsequent steps, which
# is what we want, as we need to rebuild if the sources have changed.

# Copy NVCC and the CUDA runtime from the Perforce tree.
ADD bin /sw/gpgpu/bin

# Copy the core CUDA headers from the Perforce tree.
ADD cuda/import/*.h* /sw/gpgpu/cuda/import/
ADD cuda/common/*.h* /sw/gpgpu/cuda/common/
ADD cuda/tools/cudart/*.h* /sw/gpgpu/cuda/tools/cudart/
ADD cuda/tools/cudart/nvfunctional /sw/gpgpu/cuda/tools/cudart/
ADD cuda/tools/cnprt/*.h* /sw/gpgpu/cuda/tools/cnprt/
ADD cuda/tools/cooperative_groups/*.h* /sw/gpgpu/cuda/tools/cooperative_groups/
ADD cuda/tools/cudart/cudart_etbl/*.h* /sw/gpgpu/cuda/tools/cudart/cudart_etbl/
ADD opencl/import/cl_rel/CL/*.h* /sw/gpgpu/opencl/import/cl_rel/CL/

# Copy libcu++ sources from the Perforce tree.
ADD libcudacxx /sw/gpgpu/libcudacxx

# Configure libc++ tests.
RUN cd /sw/gpgpu/libcudacxx/libcxx/build\
 && cmake ..\
 -DLIBCXX_INCLUDE_TESTS=ON\
 -DLIBCXX_INCLUDE_BENCHMARKS=OFF\
 -DLIBCXX_CXX_ABI=libsupc++\
 -DLLVM_CONFIG_PATH=$(which llvm-config-5.0)\
 -DCMAKE_C_COMPILER=gcc-5\
 -DCMAKE_CXX_COMPILER=g++-5\
 && make -j\
 2>&1 | tee /sw/gpgpu/libcudacxx/libcxx/build/libcxx_cmake.log

# Configure libcu++ tests.
RUN cd /sw/gpgpu/libcudacxx/build\
 && cmake ..\
 -DLIBCXX_INCLUDE_TESTS=ON\
 -DLIBCXX_INCLUDE_BENCHMARKS=OFF\
 -DLIBCXX_CXX_ABI=libsupc++\
 -DLLVM_CONFIG_PATH=$(which llvm-config-5.0)\
 -DCMAKE_C_COMPILER=/sw/gpgpu/bin/x86_64_Linux_release/nvcc\
 -DCMAKE_CXX_COMPILER=/sw/gpgpu/bin/x86_64_Linux_release/nvcc\
 -DLIBCXX_HOST_COMPILER=g++-5\
 2>&1 | tee /sw/gpgpu/libcudacxx/build/libcudacxx_cmake.log

# Build tests if requested.
RUN cd /sw/gpgpu/libcudacxx\
 && LIBCUDACXX_SKIP_TESTS_RUN=1\
 LIBCUDACXX_COMPUTE_ARCHS=$LIBCUDACXX_COMPUTE_ARCHS\
 LIBCUDACXX_SKIP_BASE_TESTS_BUILD=$LIBCUDACXX_SKIP_BASE_TESTS_BUILD\
 /sw/gpgpu/libcudacxx/utils/nvidia/linux/perform_tests.bash\
 --log-libcxx-results /sw/gpgpu/libcudacxx/libcxx/build/libcxx_lit.log\
 --log-libcudacxx-results /sw/gpgpu/libcudacxx/build/libcudacxx_lit.log

