# 使用官方镜像作为基础
FROM quay.io/jupyter/scipy-notebook:latest

# ===================================================================================
# 阶段 1: 以 root 身份，完成所有的环境准备和软件安装
# ===================================================================================

# 明确指定我们将在整个构建和运行过程都使用 root 用户
USER root

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
    # 经过反复验证，uv 安装脚本在 root + HOME=/home/jovyan 的环境下会安装到 /home/jovyan/.local/bin
    # 我们直接从这个确切的路径移动它
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    mv /home/jovyan/.local/bin/uv /usr/local/bin/uv && \
    \
    # 3. 安装 Rust 工具链
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    \
    # --- 决定性的核心修正 ---
    # 4. 不再依赖 .cargo/env 文件，而是直接将 cargo 的 bin 目录导出到当前 Shell 的 PATH 中
    #    这确保了后续命令一定能找到 cargo，无论 rustup 脚本的行为如何
    export PATH="/root/.cargo/bin:$PATH" && \
    \
    # 5. 安装并注册 Rust 内核到系统
    cargo install evcxr_jupyter && \
    evcxr_jupyter --install --sys-prefix && \
    \
    # 6. 使用 uv 高速安装系统级的 Python 包
    uv pip install --system --no-cache-dir jupyterhub jupyterlab-language-pack-zh-CN jupyterlab-lsp jedi-language-server && \
    \
    # 7. 最终验证所有安装
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
LABEL maintainer="Feature"
LABEL description="[ROOT USER] Jupyter notebook with system-wide Rust kernel, uv, and tools"

# CMD/ENTRYPOINT 由基础镜像继承，最终会启动 JupyterLab
# 注意：此容器将以 root 用户身份运行
