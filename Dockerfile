# 采用官方镜像作为基础
# scipy-notebook 包含了常用的科学计算包，如果不需要可以换成 jupyter/base-notebook
FROM quay.io/jupyter/scipy-notebook:latest

# ------------------------------------------------------------
# 阶段 1：以 root 身份安装系统依赖和 Python 扩展包
# ------------------------------------------------------------
# USER root

# RUN apt-get update && \
#     apt-get install -y --no-install-recommends \
#         curl \
#         iputils-ping \
#         wget \
#     && apt-get clean

# RUN cat <<EOF > /opt/conda/.condarc
# channels:
#   - conda-forge
#   - defaults
# show_channel_urls: true
# EOF

# 使用 pip 并通过国内 pypi 镜像一次性安装所有 JupyterHub 相关的 Python 扩展
RUN pip install --no-cache-dir \
    'lckr-jupyterlab-variableinspector' \
    'oauthenticator' \
    'jupyterlab-language-pack-zh-CN' \
    'jupyterlab-lsp' \
    'python-lsp-server[all]' \
    'jupyterlab_execute_time' \
    'jupyter-resource-usage' \
    'ipykernel' \
    &&\
    mamba create -n sar2real python=3.12 ipykernel --yes && \
    # 使用 mamba run 在新環境中安裝 ipykernel
    #eval "$(mamba shell hook --shell bash)" && \
    # 使用 mamba run 在新環境中執行註冊指令
    mamba run -n sar2real python -m ipykernel install --user --name "sar2real" --display-name "Python (sar2real)" && \
    mamba clean --all -f -y
    # && \
    # [重要] 使用官方脚本修复文件权限
    # fix-permissions "${CONDA_DIR}" && \
    # fix-permissions "/home/${NB_USER}"

# 设置时区
# ENV TZ=Asia/Shanghai
# RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# ------------------------------------------------------------
# 阶段 2：切回 jovyan 用户
# ------------------------------------------------------------
# USER ${NB_USER}

# COPY environment.yml /home/jovyan/environment.yml
# COPY sar2real.yml /home/jovyan/sar2real.yml

# # 工作目录保持官方默认
# WORKDIR /home/jovyan

# 元数据标签
LABEL maintainer="Feature"
LABEL description="JupyterLab with extensions for JupyterHub (dockerspawner, oauthenticator)"




