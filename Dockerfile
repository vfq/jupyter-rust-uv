# 使用官方镜像作为基础
FROM quay.io/jupyter/scipy-notebook:latest

# ===================================================================================
# 阶段 1: 以 root 身份，完成所有的环境准备和软件安装
# ===================================================================================

# 明确指定我们将在整个构建和运行过程都使用 root 用户
USER root

# 设置环境变量，将 Rust/Cargo 的路径添加到 PATH
# 这个 ENV 指令使得后续所有的 RUN 命令都能直接找到 cargo
ENV PATH="/root/.cargo/bin:${PATH}"

# 合并所有 RUN 指令以优化镜像层数和构建效率
RUN \
    # 1. 更新并安装系统依赖
    apt-get update && apt-get install -y \
        build-essential \
        cmake \
        pkg-config \
        libssl-dev \
        curl \
        iputils-ping \
        net-tools \
        dnsutils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* && \
    \
    # 2. 安装 uv
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    \
    # 3. 安装 Rust 工具链
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    \
    # 核心修正：删除下面这行，因为它不再被创建，而且 ENV 已经使它变得多余
    # . "/root/.cargo/env" && \
    \
    # 4. 安装并注册 Rust 内核到系统
    #    因为 ENV 已设置 PATH，所以 cargo 命令可以直接被找到
    cargo install evcxr_jupyter && \
    evcxr_jupyter --install --sys-prefix && \
    \
    # 5. 使用 uv 高速安装系统级的 Python 包
    uv pip install --system --no-cache-dir jupyterhub jupyterlab-language-pack-zh-CN jupyterlab-lsp jedi-language-server && \
    \
    # 6. 最终验证
    echo "--- Verifying installations ---" && \
    jupyter kernelspec list && \
    uv --version && \
    cargo --version && \
    which jupyterhub-singleuser && \
    echo "--- Verification complete ---"


# ===================================================================================
# 阶段 2: 设置最终的容器工作环境
# ===================================================================================

# 设置工作目录到 /home/jovyan，以使用 K8s 挂载的持久卷
WORKDIR /home/jovyan

# 添加镜像元数据标签
LABEL maintainer="JupyterHub"
LABEL description="[ROOT USER] Jupyter notebook with system-wide Rust kernel, uv, and tools"

# CMD/ENTRYPOINT 由基础镜像继承，最终会启动 JupyterLab
# 注意：此容器将以 root 用户身份运行
