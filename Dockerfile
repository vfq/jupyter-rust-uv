FROM quay.io/jupyter/scipy-notebook:latest

# ===================================================================================
# 阶段 1: 以 root 身份安装所有系统级的 OS 依赖和工具
# ===================================================================================
USER root

RUN apt-get update && apt-get install -y \
    build-essential cmake pkg-config libssl-dev curl \
    iputils-ping net-tools dnsutils \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 安装 uv 并移动到系统路径
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    mv /root/.cargo/bin/uv /usr/local/bin/uv


# ===================================================================================
# 阶段 2: 切换到 jovyan 用户，编译和安装 Rust
# ===================================================================================
USER jovyan

# 不再需要在这里设置 ENV PATH，因为我们将使用更可靠的方式
# ENV PATH="/home/jovyan/.cargo/bin:${PATH}"

RUN \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    . "/home/jovyan/.cargo/env" && \
    cargo install evcxr_jupyter


# ===================================================================================
# 阶段 3: 切换回 root 用户，执行系统集成任务
# ===================================================================================
USER root

# 核心修正：创建一个系统级的 profile 脚本，为所有用户设置 cargo 的 PATH
RUN echo 'export PATH="/home/jovyan/.cargo/bin:$PATH"' > /etc/profile.d/cargo.sh && \
    chmod +x /etc/profile.d/cargo.sh

RUN \
    /home/jovyan/.cargo/bin/evcxr_jupyter --install --sys-prefix && \
    uv pip install --system --no-cache-dir jupyterhub jupyterlab-language-pack-zh-CN jupyterlab-lsp jedi-language-server && \
    echo "--- Verifying installations ---" && \
    jupyter kernelspec list && \
    uv --version && \
    # 在验证时也需要 source 一下，因为当前 RUN 会话还未加载 profile.d
    . /etc/profile.d/cargo.sh && cargo --version && \
    which jupyterhub-singleuser && \
    echo "--- Verification complete ---"


# ===================================================================================
# 阶段 4: 最终切换回非 root 用户并设置工作目录，保证运行时安全
# ===================================================================================
USER jovyan

WORKDIR /home/jovyan

LABEL maintainer="JupyterHub"
LABEL description="Jupyter notebook with system-wide Rust kernel, uv, and tools for JupyterHub"
