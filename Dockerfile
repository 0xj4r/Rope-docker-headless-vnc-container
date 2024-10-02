FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04 as base

ENV REFRESHED_AT 2024-08-12
LABEL io.k8s.description="Headless VNC Container with Xfce window manager, firefox and chromium" \
      io.k8s.display-name="Headless VNC Container based on Debian" \
      io.openshift.expose-services="6901:http,5901:xvnc" \
      io.openshift.tags="vnc, debian, xfce" \
      io.openshift.non-scalable=true

ENV DISPLAY=:1 VNC_PORT=5901 NO_VNC_PORT=6901 \
    HOME=/workspace TERM=xterm STARTUPDIR=/dockerstartup INST_SCRIPTS=/workspace/install \
    NO_VNC_HOME=/workspace/noVNC DEBIAN_FRONTEND=noninteractive \
    VNC_COL_DEPTH=24 VNC_PW=vncpassword VNC_VIEW_ONLY=false TZ=Asia/Seoul

WORKDIR $HOME

# Combine RUN statements and clean up to minimize layers and space
RUN apt-get update && apt-get install -y \
    wget git build-essential software-properties-common apt-transport-https \
    ca-certificates unzip ffmpeg jq tzdata && \
    ln -fs /usr/share/zoneinfo/$TZ /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Miniconda and clean up
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh && \
    bash miniconda.sh -b -p /opt/conda && rm miniconda.sh && \
    /opt/conda/bin/conda clean --all -y

ENV PATH /opt/conda/bin:$PATH

# Add all install scripts and set permissions
ADD ./src/common/install/ $INST_SCRIPTS/
ADD ./src/debian/install/ $INST_SCRIPTS/
RUN find $INST_SCRIPTS -type f -exec chmod +x {} \;

# Ensure /dockerstartup directory exists
RUN mkdir -p /dockerstartup

# Install necessary tools and clean up intermediate files
RUN $INST_SCRIPTS/tools.sh && \
    $INST_SCRIPTS/install_custom_fonts.sh && \
    $INST_SCRIPTS/tigervnc.sh && \
    $INST_SCRIPTS/no_vnc_1.5.0.sh && \
    $INST_SCRIPTS/firefox.sh && \
    $INST_SCRIPTS/xfce_ui.sh && \
    $INST_SCRIPTS/libnss_wrapper.sh && \
    $INST_SCRIPTS/set_user_permission.sh $STARTUPDIR $HOME && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

# Create and activate Conda environment, install Rope
RUN conda create -n Rope python=3.10.13 && conda clean --all -y && \
    echo "source activate Rope" >> ~/.bashrc && \
    git clone https://github.com/Hillobar/Rope.git /workspace/Rope && \
    pip install --upgrade pip setuptools==57.5.0 wheel && \
    pip install -r /workspace/Rope/requirements.txt --no-cache-dir

COPY ./src/Models.py /workspace/Rope/rope/Models.py

# Download models
RUN mkdir -p /workspace/Rope/models && \
    wget -qO- https://api.github.com/repos/Hillobar/Rope/releases/tags/Sapphire | jq -r '.assets[] | .browser_download_url' | xargs -n 1 wget -P /workspace/Rope/models

# # Install additional tools
# RUN pip install jupyterlab && \
#     wget -O - https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

EXPOSE 8080 8585

COPY ./src/vnc_startup_jupyterlab_filebrowser.sh /dockerstartup/vnc_startup.sh
RUN chmod 765 /dockerstartup/vnc_startup.sh

ENTRYPOINT ["/dockerstartup/vnc_startup.sh"]
CMD ["--wait"]
