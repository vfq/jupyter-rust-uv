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
# 阶段 2: 切换到 jovyan 用户，完成所有需要在此用户环境下编译/安装的工具
# ===================================================================================
USER jovyan

# 为用户环境设置 PATH
ENV PATH="/home/jovyan/.cargo/bin:/home/jovyan/.local/bin:${PATH}"

RUN \
    # 1. 安装 uv (它将被安装到 $HOME/.local/bin)
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    \
    # 2. 安装 Rust 工具链
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    \
    # 3. 加载 cargo 环境变量
    . "/home/jovyan/.cargo/env" && \
    \
    # 4. 编译和安装 evcxr_jupyter 到用户目录
    cargo install evcxr_jupyter


# ===================================================================================
# 阶段 3: 切换回 root 用户，执行所有需要管理员权限的“系统集成”任务
# ===================================================================================
USER root

RUN \
    # 1. 核心修正：从确切的源路径移动 uv 到系统路径
    mv /home/jovyan/.local/bin/uv /usr/local/bin/uv && \
    \
    # 2. 将 evcxr_jupyter 内核注册到系统
    /home/jovyan/.cargo/bin/evcxr_jupyter --install --sys-prefix && \
    \
    # 3. 安装系统级的 Python 包
    uv pip install --system --no-cache-dir jupyterhub jupyterlab-language-pack-zh-CN jupyterlab-lsp jedi-language-server && \
    \
    # 4. 最终验证
    echo "--- Verifying installations ---" && \
    jupyter kernelspec list && \
    uv --version && \
    /home/jovyan/.cargo/bin/cargo --version && \
    which jupyterhub-singleuser && \
    echo "--- Verification complete ---"


# ===================================================================================
# 阶段 4: 最终切换回非 root 用户并设置工作目录，保证运行时安全
# ===================================================================================
USER jovyan

WORKDIR /home/jovyan

LABEL maintainer="Feature"
LABEL description="Jupyter notebook with system-wide Rust kernel, uv, and tools for JupyterHub"
