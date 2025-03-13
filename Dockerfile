ARG CUDA_VERSION="12.4.1"
ARG CUDNN_VERSION=""
ARG UBUNTU_VERSION="22.04"
ARG PYTORCH_VERSION="2.5.1"
ARG CUDA_PYTORCH="124"
ARG GRADIO_PORT=7860
ARG JUPYTER_PORT=8888
ARG DOCKER_FROM=nvidia/cuda:$CUDA_VERSION-cudnn$CUDNN_VERSION-devel-ubuntu$UBUNTU_VERSION

FROM $DOCKER_FROM AS builder

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    CONDA_DIR=/opt/conda \
    PATH="$CONDA_DIR/bin:$PATH"

WORKDIR /workspace

RUN apt-get update && apt-get install -y \
    wget git git-lfs libtinfo5 libgl1-mesa-glx \
    build-essential ca-certificates cmake curl \
    libcurl4-openssl-dev libglib2.0-0 libsm6 \
    libssl-dev libxext6 libxrender-dev \
    software-properties-common openssh-client \
    unzip zlib1g-dev libc6-dev vim jq \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p $CONDA_DIR && \
    rm /tmp/miniconda.sh

RUN conda create -n yue python=3.12 -y && \
    conda install -n yue -y -c conda-forge openmpi mpi4py conda-pack && \
    conda clean --all -y

RUN conda run -n yue pip install torch==$PYTORCH_VERSION torchvision torchaudio --index-url https://download.pytorch.org/whl/cu$CUDA_PYTORCH

RUN conda run -n yue pip install --no-cache-dir \
    onnxruntime-gpu tensorrt huggingface_hub[cli]

RUN conda run -n yue conda-pack -o /tmp/yue.tar.gz

FROM nvidia/cuda:$CUDA_VERSION-runtime-ubuntu$UBUNTU_VERSION AS runtime

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    PATH="/opt/envs/yue/bin:$PATH" \
    LD_LIBRARY_PATH="/opt/envs/yue/lib:$LD_LIBRARY_PATH"

WORKDIR /workspace/YuE

RUN apt-get update && apt-get install -y \
    git git-lfs libtinfo5 libgl1-mesa-glx nginx && \
    git lfs install && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /tmp/yue.tar.gz /tmp/yue.tar.gz
RUN mkdir -p /opt/envs/yue && tar -xzf /tmp/yue.tar.gz -C /opt/envs/yue && rm /tmp/yue.tar.gz
RUN ln -s /opt/envs/yue/bin/python /usr/local/bin/python

RUN /opt/envs/yue/bin/python -m pip install --no-cache-dir -r requirements.txt

COPY --chmod=755 . /YuE-Interface
COPY --chmod=755 docker/initialize.sh /initialize.sh
COPY --chmod=755 docker/entrypoint.sh /entrypoint.sh

EXPOSE $GRADIO_PORT $JUPYTER_PORT

CMD [ "/initialize.sh" ]
