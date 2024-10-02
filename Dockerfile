# Stage 1: Builder for installing dependencies
FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04 AS builder

# Install required system packages and dependencies for building
RUN apt-get update && apt-get install -y \
    build-essential git wget curl python3-dev python3-pip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /workspace

# Install Micromamba (if using Conda) or setup pip (if using Python pip)
RUN curl -L https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba -C /usr/local/bin/ && \
    micromamba shell init -s bash -p /opt/conda && \
    micromamba create -y -n Rope python=3.10.13 && micromamba clean --all -y

# Copy the requirements file
COPY requirements.txt /workspace/requirements.txt

# Install dependencies via pip using binary wheels to reduce space
RUN pip install --prefer-binary -r requirements.txt --no-cache-dir

# Clean up any caches or build artifacts to reduce image size
RUN apt-get purge -y --auto-remove build-essential python3-dev && \
    rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* /root/.cache/*

# Stage 2: Final runtime environment
FROM nvidia/cuda:11.8.0-runtime-ubuntu22.04

# Set working directory
WORKDIR /workspace

# Copy only the installed dependencies from the builder stage
COPY --from=builder /workspace /workspace

# Expose VNC and noVNC ports for remote access
EXPOSE 5901 6901

# Copy VNC startup script (assumed you have this script for VNC setup)
COPY ./src/vnc_startup.sh /dockerstartup/vnc_startup.sh
RUN chmod +x /dockerstartup/vnc_startup.sh

# Set command to start services
CMD ["/dockerstartup/vnc_startup.sh"]
