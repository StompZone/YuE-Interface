ARG CONDAENV="yue"
ARG CONDA_PATH="/opt/conda"
ARG CUDA_PYTORCH="124"
ARG CUDA_VERSION="12.4.1"
ARG CUDNN_VERSION=""
ARG DOCKER_FROM_BUILD=nvidia/cuda:$CUDA_VERSION-cudnn$CUDNN_VERSION-devel-ubuntu$UBUNTU_VERSION
ARG DOCKER_FROM_RUNTIME=nvidia/cuda:$CUDA_VERSION-runtime-ubuntu$UBUNTU_VERSION
ARG GRADIO_PORT=7860
ARG JUPYTER_PORT=8888
ARG MINICONDA_INSTALLER="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
ARG PYTHON_VERSION="3.12"
ARG PYTORCH_VERSION="2.5.1"
ARG UBUNTU_VERSION="22.04"

FROM ${DOCKER_FROM_BUILD} AS builder

ARG CONDAENV
ARG CONDA_PATH
ARG CUDA_PYTORCH
ARG CUDA_VERSION
ARG CUDNN_VERSION
ARG DOCKER_FROM_BUILD
ARG DOCKER_FROM_RUNTIME
ARG GRADIO_PORT
ARG JUPYTER_PORT
ARG MINICONDA_INSTALLER
ARG PYTHON_VERSION
ARG PYTORCH_VERSION
ARG UBUNTU_VERSION

ENV DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC \
	LD_LIBRARY_PATH="/opt/envs/$CONDAENV/lib:$LD_LIBRARY_PATH" \
    PATH="${CONDA_PATH}/bin:/opt/envs/${CONDAENV}/bin:${PATH}" \
	CUDA_VERSION=${CUDA_VERSION} CUDNN_VERSION=${CUDNN_VERSION} \
    UBUNTU_VERSION=${UBUNTU_VERSION} PYTORCH_VERSION=${PYTORCH_VERSION} \
    CUDA_PYTORCH=${CUDA_PYTORCH} GRADIO_PORT=${GRADIO_PORT} \
    JUPYTER_PORT=${JUPYTER_PORT} MINICONDA_INSTALLER=${MINICONDA_INSTALLER} \
    CONDA_PATH=${CONDA_PATH} PYTHON_VERSION=${PYTHON_VERSION} \
    CONDAENV=${CONDAENV} DOCKER_FROM_BUILD=${DOCKER_FROM_BUILD} \
	DOCKER_FROM_RUNTIME=${DOCKER_FROM_RUNTIME}

WORKDIR /workspace

RUN <<EOF
apt-get update
apt-get install -y --no-install-recommends --option Acquire::Queue-Mode=access --option \
    Acquire::Retries=3 wget git git-lfs libtinfo5 libgl1-mesa-glx build-essential \
    ca-certificates cmake curl libcurl4-openssl-dev libglib2.0-0 libsm6 libssl-dev libxext6 \
    libxrender-dev software-properties-common openssh-client unzip zlib1g-dev libc6-dev vim jq
apt-get clean
rm -rf /var/lib/apt/lists/*
mkdir -p ${CONDA_PATH}
wget ${MINICONDA_INSTALLER} -O /tmp/miniconda.sh
bash /tmp/miniconda.sh -b -p ${CONDA_PATH}
rm /tmp/miniconda.sh
conda create -n ${CONDAENV} -y python=${PYTHON_VERSION} -c conda-forge \
    openmpi mpi4py conda-pack pytorch=${PYTORCH_VERSION} torchvision torchaudio
conda run -n ${CONDAENV} pip install --no-cache-dir --use-feature=fast-deps \
    onnxruntime-gpu tensorrt huggingface_hub[cli]
conda clean --all -y
conda run -n ${CONDAENV} conda-pack -o /tmp/yue.tar.gz
EOF

FROM ${DOCKER_FROM_RUNTIME} AS runtime

ARG CONDAENV
ARG CONDA_PATH
ARG CUDA_PYTORCH
ARG CUDA_VERSION
ARG CUDNN_VERSION
ARG DOCKER_FROM_BUILD
ARG DOCKER_FROM_RUNTIME
ARG GRADIO_PORT
ARG JUPYTER_PORT
ARG MINICONDA_INSTALLER
ARG PYTHON_VERSION
ARG PYTORCH_VERSION
ARG UBUNTU_VERSION

ENV DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC \
	LD_LIBRARY_PATH="/opt/envs/$CONDAENV/lib:$LD_LIBRARY_PATH" \
    PATH="${CONDA_PATH}/bin:/opt/envs/${CONDAENV}/bin:${PATH}" \
	CUDA_VERSION=${CUDA_VERSION} CUDNN_VERSION=${CUDNN_VERSION} \
    UBUNTU_VERSION=${UBUNTU_VERSION} PYTORCH_VERSION=${PYTORCH_VERSION} \
    CUDA_PYTORCH=${CUDA_PYTORCH} GRADIO_PORT=${GRADIO_PORT} \
    JUPYTER_PORT=${JUPYTER_PORT} MINICONDA_INSTALLER=${MINICONDA_INSTALLER} \
    CONDA_PATH=${CONDA_PATH} PYTHON_VERSION=${PYTHON_VERSION} \
    CONDAENV=${CONDAENV} DOCKER_FROM_BUILD=${DOCKER_FROM_BUILD} \
	DOCKER_FROM_RUNTIME=${DOCKER_FROM_RUNTIME}

WORKDIR /workspace/YuE-Interface

RUN <<EOF
apt-get update
apt-get install -y --no-install-recommends \
    git git-lfs libtinfo5 libgl1-mesa-glx nginx
git lfs install
apt-get clean
rm -rf /var/lib/apt/lists/*
EOF

COPY --from=builder /tmp/yue.tar.gz /tmp/yue.tar.gz

RUN <<EOF
mkdir -p /opt/envs/$CONDAENV
tar -xzf /tmp/yue.tar.gz -C /opt/envs/$CONDAENV
rm /tmp/yue.tar.gz
ln -s /opt/envs/$CONDAENV/bin/python /usr/local/bin/python
EOF

COPY --chmod=755 . /YuE-Interface
COPY --chmod=755 docker/initialize.sh /initialize.sh
COPY --chmod=755 docker/entrypoint.sh /entrypoint.sh

EXPOSE ${GRADIO_PORT} ${JUPYTER_PORT}

CMD [ "/initialize.sh" ]
