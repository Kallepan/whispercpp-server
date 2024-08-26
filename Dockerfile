ARG UBUNTU_VERSION=24.04
# This needs to generally match the container host's environment.
ARG CUDA_VERSION=12.6.0
ARG CUDA_MAIN_VERSION=12.6
# Target the CUDA build image
ARG BASE_CUDA_DEV_CONTAINER=nvidia/cuda:${CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION}
# Target the CUDA runtime image
ARG BASE_CUDA_RUN_CONTAINER=nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu${UBUNTU_VERSION}

### Build image ###
FROM ${BASE_CUDA_DEV_CONTAINER} AS build

# Unless otherwise specified, we make a fat build.
ARG CUDA_DOCKER_ARCH=all
# Set nvcc architecture
ENV CUDA_DOCKER_ARCH=${CUDA_DOCKER_ARCH}
# Enable cuBLAS
ENV GGML_CUDA=1

RUN apt-get update \
    && apt-get install -y build-essential git \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Fetch whisper.cpp
RUN git clone https://github.com/ggerganov/whisper.cpp.git
WORKDIR /whisper.cpp

# Ref: https://stackoverflow.com/a/53464012
ENV CUDA_MAIN_VERSION=${CUDA_MAIN_VERSION}
ENV LD_LIBRARY_PATH /usr/local/cuda-${CUDA_MAIN_VERSION}/compat:$LD_LIBRARY_PATH

RUN make server

### Runtime image ###
FROM ${BASE_CUDA_RUN_CONTAINER} AS runtime
ENV CUDA_MAIN_VERSION=${CUDA_MAIN_VERSION}
ENV LD_LIBRARY_PATH /usr/local/cuda-${CUDA_MAIN_VERSION}/compat:$LD_LIBRARY_PATH
WORKDIR /whisper.cpp

RUN apt-get update && \
    apt-get install -y curl ffmpeg \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*
    
COPY --from=build /whisper.cpp /whisper.cpp

# entrypoint.sh
COPY entrypoint.sh /whisper.cpp
RUN chmod +x /whisper.cpp/entrypoint.sh

# Create non-root user
RUN useradd -ms /bin/bash whispercpp
RUN chown -R whispercpp:whispercpp /whisper.cpp
USER whispercpp

EXPOSE 8080

ENTRYPOINT [ "/whisper.cpp/entrypoint.sh" ]
