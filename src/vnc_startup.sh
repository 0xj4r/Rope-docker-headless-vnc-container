#!/bin/bash

# Set the display number for the VNC server (default: :1)
DISPLAY_NUM=1

# Start the VNC server with the specified display and resolution
vncserver :$DISPLAY_NUM -geometry 1280x1024 -depth $VNC_COL_DEPTH

echo "VNC server started on display :$DISPLAY_NUM with resolution 1280x1024"

# Start noVNC (web-based VNC) on the specified port, linking it to the VNC server
$NO_VNC_HOME/utils/launch.sh --vnc localhost:$VNC_PORT --listen $NO_VNC_PORT &

echo "noVNC web client started on port $NO_VNC_PORT, accessible via web browser."

# Keep the container running
tail -f /dev/null
