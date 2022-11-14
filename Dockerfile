
FROM nvidia/cuda:11.6.2-cudnn8-runtime-ubuntu20.04
LABEL authors="William da Rosa Frohlich <wrfrohlich@hotmail.com>"

RUN chmod 1777 /tmp && chmod 1777 /var/tmp

############################################################################
#################### Dependency: jupyter/base-image ########################
############################################################################

# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

# Ubuntu 20.04 (focal)
# https://hub.docker.com/_/ubuntu/?tab=tags&name=focal

ARG ROOT_CONTAINER=ubuntu:focal

LABEL maintainer="Jupyter Project <jupyter@googlegroups.com>"
ARG NB_USER="coeus"
ARG NB_UID="1000"
ARG NB_GID="100"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update --yes && \
    apt-get upgrade --yes && \
    apt-get install --yes --no-install-recommends \
    bzip2 \
    ca-certificates \
    fonts-liberation \
    locales \
    pandoc \
    run-one \
    sudo \
    tini \
    wget && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

ENV CONDA_DIR=/opt/conda \
    SHELL=/bin/bash \
    NB_USER="${NB_USER}" \
    NB_UID=${NB_UID} \
    NB_GID=${NB_GID} \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8
ENV PATH="${CONDA_DIR}/bin:${PATH}" \
    HOME="/home/${NB_USER}"

COPY fix-permissions /usr/local/bin/fix-permissions
RUN chmod a+rx /usr/local/bin/fix-permissions

RUN sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' /etc/skel/.bashrc && \
   echo 'eval "$(command conda shell.bash hook 2> /dev/null)"' >> /etc/skel/.bashrc

RUN echo "auth requisite pam_deny.so" >> /etc/pam.d/su && \
    sed -i.bak -e 's/^%admin/#%admin/' /etc/sudoers && \
    sed -i.bak -e 's/^%sudo/#%sudo/' /etc/sudoers && \
    useradd -l -m -s /bin/bash -N -u "${NB_UID}" "${NB_USER}" && \
    mkdir -p "${CONDA_DIR}" && \
    chown "${NB_USER}:${NB_GID}" "${CONDA_DIR}" && \
    chmod g+w /etc/passwd && \
    fix-permissions "${HOME}" && \
    fix-permissions "${CONDA_DIR}"

USER ${NB_UID}

ARG PYTHON_VERSION=3.10

RUN mkdir "/home/${NB_USER}/work" && \
    fix-permissions "/home/${NB_USER}"

COPY --chown="${NB_UID}:${NB_GID}" initial-condarc "${CONDA_DIR}/.condarc"
WORKDIR /tmp
RUN set -x && \
    arch=$(uname -m) && \
    if [ "${arch}" = "x86_64" ]; then \
        arch="64"; \
    fi && \
    wget -qO /tmp/micromamba.tar.bz2 \
        "https://micromamba.snakepit.net/api/micromamba/linux-${arch}/latest" && \
    tar -xvjf /tmp/micromamba.tar.bz2 --strip-components=1 bin/micromamba && \
    rm /tmp/micromamba.tar.bz2 && \
    PYTHON_SPECIFIER="python=${PYTHON_VERSION}" && \
    if [[ "${PYTHON_VERSION}" == "default" ]]; then PYTHON_SPECIFIER="python"; fi && \
    ./micromamba install \
        --root-prefix="${CONDA_DIR}" \
        --prefix="${CONDA_DIR}" \
        --yes \
        "${PYTHON_SPECIFIER}" \
        'mamba' \
        'notebook' \
        'jupyterhub' \
        'jupyterlab' && \
    rm micromamba && \
    mamba list python | grep '^python ' | tr -s ' ' | cut -d ' ' -f 1,2 >> "${CONDA_DIR}/conda-meta/pinned" && \
    jupyter notebook --generate-config && \
    mamba clean --all -f -y && \
    npm cache clean --force && \
    jupyter lab clean && \
    rm -rf "/home/${NB_USER}/.cache/yarn" && \
    fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"

EXPOSE 8888

ENTRYPOINT ["tini", "-g", "--"]
CMD ["start-notebook.sh"]

COPY start.sh start-notebook.sh start-singleuser.sh /usr/local/bin/

COPY jupyter_server_config.py /etc/jupyter/

USER root

RUN sed -re "s/c.ServerApp/c.NotebookApp/g" \
    /etc/jupyter/jupyter_server_config.py > /etc/jupyter/jupyter_notebook_config.py && \
    fix-permissions /etc/jupyter/

HEALTHCHECK  --interval=15s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -O- --no-verbose --tries=1 --no-check-certificate \
    http${GEN_CERT:+s}://localhost:8888${JUPYTERHUB_SERVICE_PREFIX:-/}api || exit 1

USER ${NB_UID}

WORKDIR "${HOME}"

############################################################################
################# Dependency: jupyter/minimal-notebook #####################
############################################################################

# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

ARG OWNER=jupyter

LABEL maintainer="Jupyter Project <jupyter@googlegroups.com>"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

# Install all OS dependencies
RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends \
    git \
    nano-tiny \
    tzdata \
    unzip \
    vim-tiny \
    inkscape \
    openssh-client \
    less \
    texlive-xetex \
    texlive-fonts-recommended \
    texlive-plain-generic && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/nano nano /bin/nano-tiny 10

USER ${NB_UID}

############################################################################
################# Dependency: jupyter/scipy-notebook #######################
############################################################################

# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

ARG OWNER=jupyter

LABEL maintainer="Jupyter Project <jupyter@googlegroups.com>"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends \
    build-essential \
    cm-super \
    dvipng \
    ffmpeg && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

USER ${NB_UID}

RUN mamba install --quiet --yes \
    'altair' \
    'beautifulsoup4' \
    'bokeh' \
    'bottleneck' \
    'cloudpickle' \
    'conda-forge::blas=*=openblas' \
    'cython' \
    'dask' \
    'dill' \
    'h5py' \
    'ipympl'\
    'ipywidgets' \
    'matplotlib-base' \
    'numba' \
    'numexpr' \
    'pandas' \
    'patsy' \
    'protobuf' \
    'pytables' \
    'scikit-image' \
    'scikit-learn' \
    'scipy' \
    'seaborn' \
    'sqlalchemy' \
    'statsmodels' \
    'sympy' \
    'widgetsnbextension'\
    'xlrd' && \
    mamba clean --all -f -y && \
    fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"

WORKDIR /tmp
RUN git clone https://github.com/PAIR-code/facets.git && \
    jupyter nbextension install facets/facets-dist/ --sys-prefix && \
    rm -rf /tmp/facets && \
    fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"

ENV XDG_CACHE_HOME="/home/${NB_USER}/.cache/"

RUN MPLBACKEND=Agg python -c "import matplotlib.pyplot" && \
    fix-permissions "/home/${NB_USER}"

USER ${NB_UID}

WORKDIR "${HOME}"

############################################################################
########################## Dependency: gpulibs #############################
############################################################################

LABEL maintainer="William da Rosa Frohlich <wrfrohlich@hotmail.com>"

RUN pip install --upgrade pip && \
    pip install --no-cache-dir "tensorflow==2.8.2"
RUN pip install --upgrade pip && \
    pip install --no-cache-dir keras==2.8

RUN conda install --quiet --yes \
    pyyaml mkl mkl-include setuptools cmake cffi typing && \
    conda clean --all -f -y && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

RUN pip install --no-cache-dir torch torchvision torchaudio torchviz \
    --extra-index-url https://download.pytorch.org/whl/cu116

USER root

RUN apt-get update && \
    apt-get install -y cmake libncurses5-dev libncursesw5-dev git && \
    rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/Syllo/nvtop.git /run/nvtop && \
    mkdir -p /run/nvtop/build && cd /run/nvtop/build && \
    (cmake .. -DNVML_RETRIEVE_HEADER_ONLINE=True 2> /dev/null || echo "cmake was not successful") && \
    (make 2> /dev/null || echo "make was not successful") && \
    (make install 2> /dev/null || echo "make install was not successful") && \
    cd /tmp && rm -rf /tmp/nvtop

RUN fix-permissions /home/$NB_USER

USER $NB_UID

############################################################################
############################ Useful packages ###############################
############################################################################

LABEL authors="William da Rosa Frohlich <wrfrohlich@hotmail.com>"

USER root

RUN pip install --no-cache-dir ipyleaflet "plotly>=4.14.3" "ipywidgets>=7.5"

RUN set -ex \
 && buildDeps=' \
    graphviz==0.19.1 \
' \
 && apt-get update \
 && apt-get -y install htop apt-utils iputils-ping graphviz libgraphviz-dev openssh-client \
 && pip install --no-cache-dir $buildDeps

RUN fix-permissions $CONDA_DIR
RUN pip install jupyterlab-drawio
RUN jupyter nbextension enable --py --sys-prefix ipyleaflet
RUN jupyter labextension install jupyterlab-plotly
RUN jupyter labextension install @jupyter-widgets/jupyterlab-manager plotlywidget
RUN pip install --no-cache-dir jupyter_contrib_nbextensions \
    jupyter_nbextensions_configurator rise

RUN jupyter labextension install @ijmbarr/jupyterlab_spellchecker

RUN fix-permissions /home/$NB_USER

USER $NB_UID

COPY jupyter_notebook_config.json /etc/jupyter/
