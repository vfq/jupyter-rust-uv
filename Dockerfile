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
# ===================================================================================
USER jovyan

# 预先创建相关目录，避免不存在
RUN mkdir -p /home/jovyan/.cargo/bin /home/jovyan/.local/bin

# 设置 PATH，确保后续 RUN 都能用到 cargo、uv、pip3 等
ENV PATH="/home/jovyan/.cargo/bin:/home/jovyan/.local/bin:${PATH}"

# 1. 安装 Rust 工具链
# rustup 会自动把 cargo、rustc 装进 ~/.cargo/bin
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && /home/jovyan/.cargo/bin/rustc --version \
    && /home/jovyan/.cargo/bin/cargo --version

# 2. 编译和安装 evcxr_jupyter 到用户目录
RUN /home/jovyan/.cargo/bin/cargo install evcxr_jupyter \
    && /home/jovyan/.cargo/bin/evcxr_jupyter --install \
    && /home/jovyan/.cargo/bin/cargo install --git https://github.com/astral-sh/uv uv \
    && /home/jovyan/.cargo/bin/uv --version

# 3. 使用 uv 安装 Python 包
RUN /home/jovyan/.cargo/bin/uv pip install --system --no-cache-dir \
        jupyterlab-language-pack-zh-CN jupyterlab-lsp jedi-language-server

WORKDIR /home/jovyan

LABEL maintainer="Feature"
LABEL description="[SECURE] Jupyter notebook with system-wide Rust kernel, uv, and tools"
