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
#   统一装到 /opt/rust，避免被 K8s PV 覆盖
# ------------------------------------------------------------
ENV RUSTUP_HOME=/opt/rust
ENV CARGO_HOME=/opt/rust
ENV PATH="/opt/rust/bin:${PATH}"

# 安装 Rust（自动把 cargo、rustc 放到 /opt/rust/bin）
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && rustc --version \
    && cargo --version

# 安装 evcxr_jupyter 并注册为系统级 kernel
RUN cargo install evcxr_jupyter \
    && evcxr_jupyter --install --sys-prefix

# 安装 uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && uv --version

# 通过软链接把常用二进制暴露到 /usr/local/bin
#（即使 PATH 被某些环境重置也找得到）
RUN ln -sf /opt/rust/bin/cargo  /usr/local/bin/cargo && \
    ln -sf /opt/rust/bin/rustc  /usr/local/bin/rustc && \
    ln -sf /opt/rust/bin/uv     /usr/local/bin/uv     && \
    ln -sf /opt/rust/bin/uvx    /usr/local/bin/uvx

# ------------------------------------------------------------
# 阶段 3：切回 jovyan 用户并安装常用 Python 包
# ------------------------------------------------------------
USER jovyan

# 用 uv 安装 Python 扩展（系统级，避免用户目录被 PV 覆盖）
RUN uv pip install --system --no-cache-dir \
        jupyterlab-language-pack-zh-CN \
        jupyterlab-lsp \
        jedi-language-server

# 工作目录保持官方默认
WORKDIR /home/jovyan

# 元数据标签
LABEL maintainer="Feature"
LABEL description="JupyterLab in K8s with Rust kernel, uv, pre-installed tools (system-wide)"
