FROM quay.io/jupyter/scipy-notebook:latest

# ===================================================================================
# 步骤 1: 以 root 用户身份，安装所有系统级的依赖和工具
# ===================================================================================
USER root

RUN apt-get update && apt-get install -y \
    build-essential cmake pkg-config libssl-dev curl \
    iputils-ping net-tools dnsutils \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 核心修正：安装 uv 后，必须手动将其移动到系统 PATH 路径中
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    mv /root/.cargo/bin/uv /usr/local/bin/uv


# ===================================================================================
# 步骤 2: 切换到 jovyan 用户，仅用于编译和安装 Rust 程序到其 home 目录
# ===================================================================================
USER jovyan

ENV PATH="/home/jovyan/.cargo/bin:${PATH}"

RUN \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    . "/home/jovyan/.cargo/env" && \
    cargo install evcxr_jupyter


# ===================================================================================
# 步骤 3: 再次切换到 root 用户，执行所有需要管理员权限的系统级安装和注册
# ===================================================================================
USER root

RUN \
    /home/jovyan/.cargo/bin/evcxr_jupyter --install --sys-prefix && \
    uv pip install --system --no-cache-dir jupyterhub jupyterlab-language-pack-zh-CN jupyterlab-lsp jedi-language-server && \
    echo "--- Verifying installations ---" && \
    jupyter kernelspec list && \
    uv --version && \
    /home/jovyan/.cargo/bin/cargo --version && \
    which jupyterhub-singleuser && \
    echo "--- Verification complete ---"


# ===================================================================================
# 步骤 4: 最终切换回非 root 用户并设置工作目录，以保证运行时安全
# ===================================================================================
USER jovyan

WORKDIR /home/jovyan

LABEL maintainer="JupyterHub"
LABEL description="Jupyter notebook with system-wide Rust kernel, uv, and tools for JupyterHub"
