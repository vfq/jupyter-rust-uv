FROM quay.io/jupyter/scipy-notebook:latest

# ===================================================================================
# 阶段 1: 以 root 身份安装系统级依赖和核心工具 (uv)
# ===================================================================================
USER root

# 合并所有 apt-get 操作以减少镜像层数
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

# 安装 uv 并将其移动到标准的系统路径 /usr/local/bin
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    mv /root/.cargo/bin/uv /usr/local/bin/uv


# ===================================================================================
# 阶段 2: 切换到 jovyan 用户，仅用于编译和安装 Rust 程序到其 home 目录
# ===================================================================================
USER jovyan

# 安装 Rust 工具链
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    # 加载 cargo 环境变量以用于本 RUN 指令后续步骤
    . "/home/jovyan/.cargo/env" && \
    # 只编译和安装 evcxr_jupyter 到 jovyan 的 home 目录
    cargo install evcxr_jupyter


# ===================================================================================
# 阶段 3: 再次切换到 root 用户，执行所有需要管理员权限的“系统集成”任务
# ===================================================================================
USER root

# 创建一个系统级的 profile 脚本，为所有用户永久性地设置 cargo 的 PATH
# 这是确保运行时 Jupyter 内核能找到 cargo 的最可靠方法
RUN echo 'export PATH="/home/jovyan/.cargo/bin:$PATH"' > /etc/profile.d/cargo.sh && \
    chmod +x /etc/profile.d/cargo.sh

# 执行需要 root 权限的安装和注册
RUN \
    # 1. 将 evcxr_jupyter 内核注册到系统，防止被挂载卷覆盖
    /home/jovyan/.cargo/bin/evcxr_jupyter --install --sys-prefix && \
    \
    # 2. 使用 uv 高速安装系统级的 Python 包
    uv pip install --system --no-cache-dir jupyterhub jupyterlab-language-pack-zh-CN jupyterlab-lsp jedi-language-server


# ===================================================================================
# 阶段 4: 最终切换回非 root 用户并设置工作目录，保证运行时安全
# ===================================================================================
USER jovyan

# 设置工作目录为用户的家目录，这是最标准的做法
# 您在 K8s 中设置的卷权限修正（fsGroup 或 lifecycleHook）会确保此目录可写
WORKDIR /home/jovyan

# 为SwarmSpawner或其它编排工具添加标签
LABEL maintainer="JupyterHub"
LABEL description="Jupyter notebook with system-wide Rust kernel, uv, and tools for JupyterHub"

# CMD/ENTRYPOINT 由 JupyterHub Spawner 在启动时提供，此处无需设置
