# Use the NVIDIA CUDA base image with CUDNN and Ubuntu 22.04 for GPU support
FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04

# Metadata and maintainers
LABEL maintainer="YourName" \
      description="Dockerfile to run Rope project with a VNC-based desktop environment."

# Environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:1 \
    VNC_PORT=5901 \
    NO_VNC_PORT=6901 \
    HOME=/workspace \
    VNC_COL_DEPTH=24 \
    VNC_PW=vncpassword \
    VNC_VIEW_ONLY=false \
    TZ=Asia/Seoul \
    CONDA_DEFAULT_ENV=Rope \
    NO_VNC_HOME=/workspace/noVNC \
    STARTUPDIR=/dockerstartup

WORKDIR $HOME

# Install necessary dependencies and clean up after installation to reduce image size
RUN apt-get update && apt-get install -y \
    xfce4 xfce4-goodies tightvncserver novnc websockify \
    git wget curl jq build-essential python3-pip python3-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Miniconda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh && \
    bash miniconda.sh -b -p /opt/conda && \
    rm miniconda.sh

# Add Conda to the PATH
ENV PATH /opt/conda/bin:$PATH

# Create and activate Conda environment with Python 3.10, then clean up
RUN conda create -n Rope python=3.10.13 && conda clean --all -y

# Make the Conda environment active for all future shells
ENV PATH /opt/conda/envs/Rope/bin:$PATH

# Clone Rope project from the Pearl branch
WORKDIR /workspace
RUN git clone -b Pearl https://github.com/Hillobar/Rope.git --depth 1

# Install Rope project dependencies via pip and clean up
WORKDIR /workspace/Rope
RUN pip install -r requirements.txt --no-cache-dir

# Download models for the Rope Pearl branch
WORKDIR /workspace/Rope/models
RUN wget -qO- https://api.github.com/repos/Hillobar/Rope/releases/tags/Pearl | \
    jq -r '.assets[] | .browser_download_url' | xargs -n 1 wget

# Setup VNC password
RUN mkdir -p ~/.vnc && echo "$VNC_PW" | vncpasswd -f > ~/.vnc/passwd && chmod 600 ~/.vnc/passwd

# Set up VNC and noVNC for remote access
RUN mkdir -p $STARTUPDIR $NO_VNC_HOME/utils/websockify && \
    wget https://github.com/novnc/noVNC/archive/v1.2.0.tar.gz -O - | tar xz --strip 1 -C $NO_VNC_HOME && \
    wget https://github.com/novnc/websockify/archive/v0.9.0.tar.gz -O - | tar xz --strip 1 -C $NO_VNC_HOME/utils/websockify

# Copy VNC startup script and make it executable
COPY ./src/vnc_startup.sh $STARTUPDIR/vnc_startup.sh
RUN chmod +x $STARTUPDIR/vnc_startup.sh

# Clean up git history and any leftover installation files to reduce image size
RUN rm -rf /workspace/Rope/.git /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Expose VNC and noVNC ports
EXPOSE $VNC_PORT $NO_VNC_PORT

# Set up entrypoint to start VNC server and noVNC
ENTRYPOINT ["/dockerstartup/vnc_startup.sh"]
CMD ["--wait"]
