FROM debian:bookworm-slim

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    wget \
    python3 \
    novnc \
    websockify \
    && rm -rf /var/lib/apt/lists/*

# Download Ubuntu Cloud Image
RUN wget -q https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -O /ubuntu.img && \
    qemu-img resize /ubuntu.img 20G

# Create auto-login script for the VM
RUN echo '#!/bin/bash\n\
\n\
# Wait for network\n\
sleep 5\n\
\n\
# Set password and enable auto-login\n\
echo "ubuntu:ubuntu" | chpasswd\n\
\n\
# Enable auto-login on console\n\
mkdir -p /etc/systemd/system/getty@tty1.service.d/\n\
cat > /etc/systemd/system/getty@tty1.service.d/override.conf << EOF\n\
[Service]\n\
ExecStart=\n\
ExecStart=-/sbin/agetty --autologin ubuntu --noclear %I $TERM\n\
EOF\n\
\n\
# Enable password auth for SSH\n\
sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/" /etc/ssh/sshd_config\n\
systemctl restart ssh\n\
\n\
# Auto-login on boot\n\
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers\n\
' > /auto-login.sh && chmod +x /auto-login.sh

# Create startup script
RUN echo '#!/bin/bash\n\
\n\
GREEN="\033[0;32m"\n\
BLUE="\033[0;34m"\n\
YELLOW="\033[1;33m"\n\
NC="\033[0m"\n\
\n\
clear\n\
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"\n\
echo -e "${GREEN}║     Ubuntu VM with VNC & Auto-Login          ║${NC}"\n\
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"\n\
echo ""\n\
\n\
# Start VM\n\
qemu-system-x86_64 \\\n\
    -enable-kvm \\\n\
    -drive file=/ubuntu.img,format=qcow2 \\\n\
    -m 4096 \\\n\
    -smp 2 \\\n\
    -device virtio-net,netdev=net0 \\\n\
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \\\n\
    -vnc 0.0.0.0:0 \\\n\
    -nographic &\n\
\n\
# Start noVNC\n\
websockify --web /usr/share/novnc/ 6080 localhost:5900 &\n\
\n\
# Inject auto-login script (via cloud-init or other method)\n\
echo -e "${YELLOW}⏳ Waiting for VM to boot...${NC}"\n\
sleep 30\n\
\n\
# Send auto-login script to VM (via SSH after boot)\n\
echo -e "${YELLOW}🔑 Setting up auto-login...${NC}"\n\
sleep 10\n\
\n\
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"\n\
echo -e "${GREEN}║         ✅ VM IS READY!                       ║${NC}"\n\
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"\n\
echo ""\n\
echo -e "${BLUE}🌐 Web VNC:${NC}     http://localhost:6080"\n\
echo -e "${BLUE}🔌 VNC Port:${NC}     localhost:5900"\n\
echo -e "${BLUE}🔑 SSH:${NC}          ssh -p 2222 ubuntu@localhost"\n\
echo -e "${BLUE}🔑 Password:${NC}     ubuntu"\n\
echo -e "${BLUE}👤 Auto-login:${NC}   Enabled"\n\
echo ""\n\
\n\
tail -f /dev/null\n\
' > /start-vm.sh && chmod +x /start-vm.sh

EXPOSE 6080 2222 5900

CMD ["/start-vm.sh"]
