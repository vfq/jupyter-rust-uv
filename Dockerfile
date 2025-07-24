FROM quay.io/jupyter/scipy-notebook:latest

USER root

# 安装Rust依赖
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    pkg-config \
    libssl-dev \
    curl \
    iputils-ping \
    net-tools \
    dnsutils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | sh

USER jovyan

ENV PATH="/home/jovyan/.cargo/bin:${PATH}"

# 将所有用户级的安装合并到一个 RUN 指令中
RUN \
    # 1. 安装 Rust 工具链
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    \
    # 核心修正：手动加载 cargo 的环境变量，以便在当前 shell 会话中立即生效
    . "/home/jovyan/.cargo/env" && \
    \
    # 2. 安装 Rust Kernel for Jupyter (现在可以找到 cargo 了)
    cargo install evcxr_jupyter && \
    evcxr_jupyter --install --sys-prefix && \
    \
    # 3. 安装 JupyterHub/Lab 相关 Python 包
    uv pip install --system --no-cache-dir jupyterhub jupyterlab-language-pack-zh-CN jupyterlab-lsp jedi-language-server && \
    \
    # 4. 最终验证
    echo "--- Verifying installations ---" && \
    jupyter kernelspec list && \
    uv --version && \
    cargo --version && \
    which jupyterhub-singleuser && \
    echo "--- Verification complete ---"

# 设置工作目录
WORKDIR /home/jovyan/work

# 为SwarmSpawner添加必要标签
LABEL maintainer="Feature"
LABEL description="Jupyter notebook with Rust evcxr kernel and uv for package management!"
