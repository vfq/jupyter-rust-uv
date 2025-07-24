# 使用官方镜像作为基础
FROM quay.io/jupyter/scipy-notebook:latest

# ===================================================================================
# 阶段 1: 以 root 身份安装所有系统级的 OS 依赖
# ===================================================================================
USER root

RUN apt-get update && apt-get install -y \
    build-essential cmake pkg-config libssl-dev curl \
    iputils-ping net-tools dnsutils \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ===================================================================================
# 阶段 2: 切换到 jovyan 用户，完成所有用户空间的编译和安装
# 这会将 uv, rustc, cargo, evcxr_jupyter 等都安装到 /home/jovyan 目录下
# ===================================================================================
USER jovyan

RUN \
    # 1. 安装 Rust 工具链
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 

ENV PATH="/home/jovyan/.cargo/bin:/home/jovyan/.local/bin:${PATH}"
    
    # 2. 编译和安装 evcxr_jupyter 到用户目录
RUN cargo install evcxr_jupyter && \
    evcxr_jupyter --install && \
    cargo install --git https://github.com/astral-sh/uv uv

    # 2. 将用户空间编译的 Rust 内核注册到系统路径
RUN \
    # 3. 使用系统级的 uv 安装系统级的 Python 包
    uv pip install --no-cache-dir jupyterlab-language-pack-zh-CN jupyterlab-lsp jedi-language-server

WORKDIR /home/jovyan

LABEL maintainer="Feature"
LABEL description="[SECURE] Jupyter notebook with system-wide Rust kernel, uv, and tools"
