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
    expect \
    && rm -rf /var/lib/apt/lists/*

# Download Ubuntu Server ISO
RUN wget -q --progress=bar:force https://releases.ubuntu.com/24.04/ubuntu-24.04.2-live-server-amd64.iso -O /ubuntu.iso

# Create autoinstall user-data file for unattended installation
RUN mkdir -p /autoinstall && \
    echo '#cloud-config\n\
autoinstall:\n\
  version: 1\n\
  identity:\n\
    hostname: ubuntu-vm\n\
    username: ubuntu\n\
    password: "$6$exDY1mhS4KUYCE/2$zmn9oZBnygL0T6B4j1F3gHJnvKv4GqCjLgJh5w5w5w5w5w5w5w5w5w5w5w5w5w5w5w5w5w5w5w5w5w5"  # ubuntu\n\
  locale: en_US\n\
  keyboard:\n\
    layout: us\n\
  network:\n\
    network:\n\
      version: 2\n\
      ethernets:\n\
        ens3:\n\
          dhcp4: true\n\
  storage:\n\
    layout:\n\
      name: lvm\n\
  ssh:\n\
    install-server: true\n\
    allow-pw: true\n\
  packages:\n\
    - openssh-server\n\
    - vim\n\
    - curl\n\
  user-data:\n\
    disable_root: false\n\
  late-commands:\n\
    - sed -i "s/.*PermitRootLogin.*/PermitRootLogin yes/" /target/etc/ssh/sshd_config\n\
    - echo "ubuntu:ubuntu" | chpasswd -R /target\n' > /autoinstall/user-data

# Create ISO with autoinstall (using xorriso)
RUN apt-get update && \
    apt-get install -y --no-install-recommends xorriso isolinux && \
    mkdir -p /iso-mount /iso-custom && \
    mount -o loop /ubuntu.iso /iso-mount && \
    cp -r /iso-mount/* /iso-custom/ && \
    cp /iso-mount/.disk /iso-custom/ && \
    cp /autoinstall/user-data /iso-custom/ && \
    echo "autoinstall ds=nocloud-net;s=http://_gateway:3003/" > /iso-custom/isolinux/txt.cfg && \
    xorriso -as mkisofs -r -V "Ubuntu 24.04 Autoinstall" \
      -J -b isolinux/isolinux.bin -c isolinux/boot.cat \
      -no-emul-boot -boot-load-size 4 -boot-info-table \
      -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
      -o /ubuntu-autoinstall.iso /iso-custom && \
    umount /iso-mount && \
    apt-get remove -y xorriso isolinux && \
    apt-get autoremove -y && \
    rm -rf /iso-mount /iso-custom /var/lib/apt/lists/*

# Create startup script
RUN echo '#!/bin/bash\n\
\n\
GREEN="\033[0;32m"\n\
BLUE="\033[0;34m"\n\
YELLOW="\033[1;33m"\n\
RED="\033[0;31m"\n\
NC="\033[0m"\n\
\n\
echo -e "${BLUE}================================================${NC}"\n\
echo -e "${GREEN}🚀 Ubuntu Server Auto-Installation Starting${NC}"\n\
echo -e "${BLUE}================================================${NC}"\n\
\n\
# Create disk image\n\
echo -e "${YELLOW}📦 Creating 20GB disk image...${NC}"\n\
qemu-img create -f qcow2 /disk.qcow2 20G\n\
\n\
# Start HTTP server for cloud-init\n\
echo -e "${YELLOW}🌐 Starting HTTP server for cloud-init...${NC}"\n\
cd /autoinstall && python3 -m http.server 3003 &\n\
sleep 2\n\
\n\
# Start QEMU with autoinstall\n\
echo -e "${YELLOW}🖥️  Starting VM with auto-installation...${NC}"\n\
qemu-system-x86_64 \\\n\
    -enable-kvm \\\n\
    -cdrom /ubuntu-autoinstall.iso \\\n\
    -drive file=/disk.qcow2,format=qcow2 \\\n\
    -m 6G \\\n\
    -smp 4 \\\n\
    -device virtio-net,netdev=net0 \\\n\
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \\\n\
    -vnc 0.0.0.0:0 \\\n\
    -nographic &\n\
\n\
# Start noVNC\n\
echo -e "${YELLOW}🔌 Starting noVNC websocket proxy...${NC}"\n\
websockify --web /usr/share/novnc/ 6080 localhost:5900 &\n\
sleep 2\n\
\n\
echo -e "\\n${GREEN}================================================${NC}"\n\
echo -e "${GREEN}✅ Ubuntu Server is being installed automatically!${NC}"\n\
echo -e "${BLUE}🌐 Web VNC:${NC} http://localhost:6080"\n\
echo -e "${BLUE}🔌 VNC Port:${NC} localhost:5900"\n\
echo -e "${YELLOW}⏳ Installation takes 5-10 minutes...${NC}"\n\
echo -e "${BLUE}🔑 SSH (after install):${NC} ssh -p 2222 ubuntu@localhost"\n\
echo -e "${BLUE}🔑 Password:${NC} ubuntu"\n\
echo -e "${GREEN}================================================${NC}\\n"\n\
\n\
# Wait for SSH to be ready\n\
echo -e "${YELLOW}⏳ Waiting for SSH to be ready...${NC}"\n\
attempt=0\n\
while [ $attempt -lt 60 ]; do\n\
    nc -z localhost 2222 > /dev/null 2>&1\n\
    if [ $? -eq 0 ]; then\n\
        echo -e "${GREEN}✅ SSH is ready on port 2222!${NC}"\n\
        echo -e "${GREEN}🔑 Connect: ssh -p 2222 ubuntu@localhost (password: ubuntu)${NC}"\n\
        break\n\
    fi\n\
    echo -n "."\n\
    sleep 10\n\
    attempt=$((attempt + 1))\ndone\n\
\n\
if [ $attempt -eq 60 ]; then\n\
    echo -e "${RED}⚠️  SSH not ready after 10 minutes${NC}"\n\
    echo -e "${YELLOW}Check VNC at http://localhost:6080 for progress${NC}"\n\
fi\n\
\n\
tail -f /dev/null\n\
' > /start-vm.sh && chmod +x /start-vm.sh

EXPOSE 6080 2222 5900 3003

CMD ["/start-vm.sh"]
