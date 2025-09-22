# 采用官方镜像作为基础
# scipy-notebook 包含了常用的科学计算包，如果不需要可以换成 jupyter/base-notebook
FROM quay.io/jupyter/scipy-notebook:latest

ENV MAMBA_NO_INPUT=1

RUN mamba create -n sar2real python=3.12 --yes && \
    mamba run -n sar2real pip install --no-cache-dir \
        'lckr-jupyterlab-variableinspector' \
        'oauthenticator' \
        'jupyterlab-language-pack-zh-CN' \
        'jupyterlab-lsp' \
        'python-lsp-server[all]' \
        'jupyterlab_execute_time' \
        'jupyter-resource-usage' \
        'ipykernel' && \
    mamba run -n sar2real python -m ipykernel install --sys-prefix --name "sar2real" --display-name "Python (sar2real)" && \
    # 清理缓存以减小镜像大小
    mamba clean --all -f -y

RUN echo "source /opt/conda/etc/profile.d/conda.sh && conda activate sar2real" >> /etc/bash.bashrc

ENV CONDA_DEFAULT_ENV=sar2real

# 元数据标签
LABEL maintainer="Feature"
LABEL description="JupyterLab with extensions for JupyterHub (dockerspawner, oauthenticator)"















