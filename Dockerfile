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

USER jovyan

# 核心修正：同时将 .local/bin 和 .cargo/bin 添加到 PATH
# 这样无论 uv 和 cargo 安装在哪里，都能被找到。
# 注意：我们将 ENV 指令提前，以便后续的 RUN 命令可以使用正确的 PATH。
ENV PATH="/home/jovyan/.cargo/bin:/home/jovyan/.local/bin:${PATH}"

# 将所有用户级的安装合并到一个 RUN 指令中，减少镜像层数
RUN \
    # 1. 安装 uv
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    \
    # 2. 安装 Rust
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    \
    # 3. 安装 Rust Kernel for Jupyter
    #    因为 PATH 已经设置正确，这里可以直接调用 cargo
    cargo install evcxr_jupyter && \
    evcxr_jupyter --install && \
    \
    # 4. 安装 JupyterHub/Lab 相关包
    #    使用 uv 来安装 pip 包，速度更快
    uv pip install --system --no-cache-dir jupyterlab-language-pack-zh-CN jupyterlab-lsp jedi-language-server && \
    \
    # 5. 验证所有工具是否安装成功
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
