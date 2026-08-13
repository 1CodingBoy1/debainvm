# Use Debian 12 (Bookworm) instead of outdated Buster
FROM debian:bookworm-slim

# Install minimal dependencies including VNC server
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    wget \
    python3 \
    novnc \
    websockify \
    tigervnc-standalone-server \
    x11vnc \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

# Download Ubuntu Server ISO
RUN wget -q https://releases.ubuntu.com/24.04/ubuntu-24.04.2-live-server-amd64.iso -O /ubuntu.iso

# Create startup script with proper VNC setup
RUN echo '#!/bin/bash\n\
\n\
# Colors for output\n\
GREEN="\033[0;32m"\n\
BLUE="\033[0;34m"\n\
NC="\033[0m" # No Color\n\
\n\
# Create blank 20GB disk image\n\
echo -e "${BLUE}Creating disk image...${NC}"\n\
qemu-img create -f qcow2 /disk.qcow2 20G\n\
\n\
# Start Xvfb for virtual display\n\
Xvfb :1 -screen 0 1024x768x16 &\n\
sleep 2\n\
\n\
# Start VNC server on display :1\n\
x11vnc -display :1 -forever -nopw -shared -rfbport 5900 &\n\
sleep 2\n\
\n\
# Start noVNC websocket proxy\n\
websockify --web /usr/share/novnc/ 6080 localhost:5900 &\n\
sleep 2\n\
\n\
# Start QEMU with VNC display\n\
echo -e "${GREEN}Starting QEMU with VNC...${NC}"\n\
qemu-system-x86_64 \\\n\
    -enable-kvm \\\n\
    -cdrom /ubuntu.iso \\\n\
    -drive file=/disk.qcow2,format=qcow2 \\\n\
    -m 6G \\\n\
    -smp 4 \\\n\
    -device virtio-net,netdev=net0 \\\n\
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \\\n\
    -vnc 0.0.0.0:0 \\\n\
    -nographic \\\n\
    -display vnc=0.0.0.0:0 &\n\
\n\
echo -e "\\n${GREEN}================================================${NC}"\n\
echo -e "${GREEN}Ubuntu Server Installation Starting...${NC}"\n\
echo -e "${BLUE}1. Connect to VNC via browser:${NC} http://localhost:6080"\n\
echo -e "${BLUE}2. Or use VNC client:${NC} localhost:5900"\n\
echo -e "${BLUE}3. Complete the interactive installation${NC}"\n\
echo -e "${BLUE}4. Set your username/password when prompted${NC}"\n\
echo -e "${BLUE}5. After reboot, SSH will be available on port 2222${NC}"\n\
echo -e "${GREEN}================================================${NC}\\n"\n\
\n\
# Keep container running\n\
tail -f /dev/null\n\
' > /start-vm.sh && chmod +x /start-vm.sh

EXPOSE 6080 2222 5900

CMD ["/start-vm.sh"]
