# 采用官方镜像作为基础
FROM quay.io/jupyter/scipy-notebook:latest

# ------------------------------------------------------------
# 阶段 1：以 root 身份安装系统依赖
# ------------------------------------------------------------
USER root

# 安装构建 Rust / evcxr / uv 所需的系统包
RUN apt-get update && \
    apt-get install -y \
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

# ------------------------------------------------------------
# 阶段 2：安装 Rust 工具链、evcxr kernel、uv
# 统一装到 /opt/rust，避免被 K8s PV 覆盖
# ------------------------------------------------------------

# 设置安装路径（防止挂载 HOME 导致无效）
ENV RUSTUP_HOME=/opt/rust
ENV CARGO_HOME=/opt/rust
ENV UV_INSTALL_DIR=/opt/rust/bin
ENV PATH="/opt/rust/bin:${PATH}"

# 一次性安装 Rust 和 uv
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && rustc --version \
    && cargo --version \
    && uv --version

# 安装 evcxr_jupyter 并将其移动到系统级 kernel 目录
# chown 确保 jovyan 用户有权限使用这个 kernel
RUN cargo install evcxr_jupyter && \
    evcxr_jupyter --install && \
    mkdir -p /opt/conda/share/jupyter/kernels && \
    mv /home/jovyan/.local/share/jupyter/kernels/rust /opt/conda/share/jupyter/kernels/rust && \
    chown -R jovyan:users /opt/conda/share/jupyter/kernels/rust && \
    rm -rf /home/jovyan/.local # 清理掉 root 用户在 jovyan 家目录下创建的临时文件

# --- [核心修正] ---
# 在切换回 jovyan 用户之前，将 /home/jovyan 目录的所有权完全交还给 jovyan 用户
# 这将修复所有因 root 操作导致的权限问题
RUN chown -R jovyan:users /home/jovyan/

# ------------------------------------------------------------
# 阶段 3：切回 jovyan 用户并安装常用 Python 包
# ------------------------------------------------------------
USER jovyan

# 设置环境变量为 jovyan 用户（每次 shell 启动此用户需 source 以使 cargo 有效）
RUN echo 'source /opt/rust/env 2>/dev/null || true' >> ~/.bashrc

# 用 uv 安装 Python 扩展（系统级，避免用户目录被 PV 覆盖）
RUN uv pip install --system --no-cache-dir \
        jupyterlab-language-pack-zh-CN \
        jupyterlab-lsp \
        jedi-language-server

# 工作目录保持官方默认
WORKDIR /home/jovyan

# 元数据标签
LABEL maintainer="Feature"
LABEL description="JupyterLab with Rust kernel, installed system-wide for multi-user environments (e.g., JupyterHub)"
