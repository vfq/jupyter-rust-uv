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
    # 1. 安装 uv (将被安装到 /home/jovyan/.local/bin)
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    \
    # 2. 安装 Rust 工具链
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

RUN . "${HOME}/.cargo/env"
    
    # 3. 主动将 cargo 的路径导出到当前 Shell 的 PATH 中
ENV PATH="/home/jovyan/.cargo/bin:/home/jovyan/.local/bin:${PATH}" 
    
    # 4. 编译和安装 evcxr_jupyter 到用户目录
RUN cargo install evcxr_jupyter


# ===================================================================================
# 阶段 3: 切换回 root 用户，执行所有需要管理员权限的“系统集成”任务
# ===================================================================================
USER root

RUN \
    # 1. 将用户空间安装的 uv 移动到系统路径，使其全局可用且不会被覆盖
    mv /home/jovyan/.local/bin/uv /usr/local/bin/uv

    # 2. 将用户空间编译的 Rust 内核注册到系统路径
RUN /home/jovyan/.cargo/bin/evcxr_jupyter --install --sys-prefix && \
    \
    # 3. 使用系统级的 uv 安装系统级的 Python 包
    uv pip install --system --no-cache-dir jupyterhub jupyterlab-language-pack-zh-CN jupyterlab-lsp jedi-language-server


# ===================================================================================
# 阶段 4: 最终切换回 jovyan 用户，并为其设置永久的环境变量和工作目录
# ===================================================================================
USER jovyan

# 使用 ENV 为最终的运行时环境设置 PATH，确保 jovyan 能找到 cargo
ENV PATH="/home/jovyan/.cargo/bin:${PATH}"

WORKDIR /home/jovyan

LABEL maintainer="Feature"
LABEL description="[SECURE] Jupyter notebook with system-wide Rust kernel, uv, and tools"
