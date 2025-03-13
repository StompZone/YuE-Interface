ARG CUDA_VERSION="12.4.1"
ARG CUDNN_VERSION=""
ARG UBUNTU_VERSION="22.04"
ARG PYTORCH_VERSION="2.5.1"
ARG CUDA_PYTORCH="124"
ARG GRADIO_PORT=7860
ARG JUPYTER_PORT=8888
ARG DOCKER_FROM=nvidia/cuda:$CUDA_VERSION-cudnn$CUDNN_VERSION-devel-ubuntu$UBUNTU_VERSION
ARG MINICONDA_INSTALLER=https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
ARG CONDA_PATH=/opt/conda
ARG PYTHON_VERSION="3.12"

FROM $DOCKER_FROM AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    PATH="$CONDA_PATH/bin:$PATH" \
    PYPATH="/usr/local/bin/python" \
    CONDAENV=yue

WORKDIR /workspace

RUN apt-get update && apt-get install -y --no-install-recommends \
    --option Acquire::Queue-Mode=access \
    --option Acquire::Retries=3 \
    wget git git-lfs libtinfo5 libgl1-mesa-glx \
    build-essential ca-certificates cmake curl \
    libcurl4-openssl-dev libglib2.0-0 libsm6 \
    libssl-dev libxext6 libxrender-dev \
    software-properties-common openssh-client \
    unzip zlib1g-dev libc6-dev vim jq \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN wget $MINICONDA_INSTALLER -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p $CONDA_PATH && \
    rm /tmp/miniconda.sh

RUN conda create -n $CONDAENV python=$PYTHON_VERSION -y && \
    conda install -n $CONDAENV -y -c conda-forge \
    openmpi mpi4py conda-pack \
    pytorch=$PYTORCH_VERSION torchvision torchaudio \
    && conda clean --all -y

RUN conda run -n $CONDAENV pip install --no-cache-dir --use-feature=fast-deps \
    onnxruntime-gpu tensorrt huggingface_hub[cli] && \
    conda run -n $CONDAENV conda-pack -o /tmp/yue.tar.gz

FROM nvidia/cuda:$CUDA_VERSION-runtime-ubuntu$UBUNTU_VERSION AS runtime

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    PATH="/opt/envs/$CONDAENV/bin:$PATH" \
    LD_LIBRARY_PATH="/opt/envs/$CONDAENV/lib:$LD_LIBRARY_PATH"

WORKDIR /workspace/YuE-Interface

RUN apt-get update && apt-get install -y --no-install-recommends \
    git git-lfs libtinfo5 libgl1-mesa-glx nginx && \
    git lfs install && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /tmp/yue.tar.gz /tmp/yue.tar.gz
RUN mkdir -p /opt/envs/$CONDAENV && tar -xzf /tmp/yue.tar.gz -C /opt/envs/$CONDAENV && \
    rm /tmp/yue.tar.gz && ln -s /opt/envs/$CONDAENV/bin/python /usr/local/bin/python

COPY --chmod=755 . /YuE-Interface
COPY --chmod=755 docker/initialize.sh /initialize.sh
COPY --chmod=755 docker/entrypoint.sh /entrypoint.sh

EXPOSE $GRADIO_PORT $JUPYTER_PORT

CMD [ "/initialize.sh" ]
