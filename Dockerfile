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
# 必须让所有过程看到一致的 CARGO_HOME/RUSTUP_HOME 变量
# ------------------------------------------------------------

# 设置安装路径（防止挂载 HOME 导致无效）
ENV RUSTUP_HOME=/opt/rust
ENV CARGO_HOME=/opt/rust
ENV PATH="/opt/rust/bin:${PATH}"

# 安装 Rust（自动把 cargo、rustc 放到 /opt/rust/bin）
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && rustc --version \
    && cargo --version

# 安装 evcxr_jupyter 并注册为系统级 kernel
RUN source $CARGO_HOME/env && \
    cargo install evcxr_jupyter && \
    evcxr_jupyter --install --sys-prefix

# 创建软链接确保路径通用（即使 PATH 被重置）
RUN ln -sf /opt/rust/bin/cargo /usr/local/bin/cargo && \
    ln -sf /opt/rust/bin/rustc /usr/local/bin/rustc && \
    ln -sf /opt/rust/bin/uv /usr/local/bin/uv && \
    ln -sf /opt/rust/bin/uvx /usr/local/bin/uvx

# ------------------------------------------------------------
# 阶段 3：切回 jovyan 用户并安装常用 Python 包
# ------------------------------------------------------------
USER jovyan

# 设置环境变量为 jovyan 用户（每次 shell 启动此用户需 source 以使 cargo 有效）
RUN echo 'source /opt/rust/env 2>/dev/null || true' >> ~/.bashrc

# 用 uv 安装 Python 扩展（系统级，避免用户目录被 PV 覆盖）
RUN pip install --system --no-cache-dir \
        jupyterlab-language-pack-zh-CN \
        jupyterlab-lsp \
        jedi-language-server

# 工作目录保持官方默认
WORKDIR /home/jovyan

# 元数据标签
LABEL maintainer="Feature"
LABEL description="JupyterLab in K8s with Rust kernel, pre-installed tools (system-wide)"
