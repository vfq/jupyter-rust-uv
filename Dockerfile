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

RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    mv /root/.cargo/bin/uv /usr/local/bin/uv

USER jovyan

ENV PATH="/home/jovyan/.cargo/bin:${PATH}"

# 将所有用户级的安装合并到一个 RUN 指令中，减少镜像层数
RUN \
    # 1. 安装 Rust 工具链 (rustup 推荐以普通用户身份安装)
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    \
    # 2. 安装 Rust Kernel for Jupyter
    cargo install evcxr_jupyter && \
    # 核心修正 ②: 将内核定义文件安装到系统路径，防止被覆盖
    evcxr_jupyter --install --sys-prefix && \
    \
    # 3. 安装 JupyterHub/Lab 相关 Python 包
    #    此时可以直接调用系统级的 uv，并使用 --system 在全局环境安装
    uv pip install --system --no-cache-dir jupyterhub jupyterlab-language-pack-zh-CN jupyterlab-lsp jedi-language-server && \
    \
    # 4. 最终验证所有工具是否都已正确安装并可用
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
