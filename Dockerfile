FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    wget \
    python3 \
    novnc \
    websockify \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -O /ubuntu.img && \
    qemu-img resize /ubuntu.img 20G

# Create cloud-init config with password and auto-login
RUN mkdir -p /cloud-init && \
    echo '#cloud-config\n\
password: ubuntu\n\
chpasswd: { expire: False }\n\
ssh_pwauth: True\n\
users:\n\
  - name: ubuntu\n\
    sudo: ALL=(ALL) NOPASSWD:ALL\n\
    shell: /bin/bash\n\
    lock_passwd: false\n\
    passwd: $6$exDY1mhS4KUYCE/2$zmn9oZBnygL0T6B4j1F3gHJnvKv4GqCjLgJh5w5w5w5w5w5w5w5w5w5w5w5w5w5w5w5w5w5w5w5w5w5\n\
packages:\n\
  - openssh-server\n\
runcmd:\n\
  - echo "ubuntu:ubuntu" | chpasswd\n\
  - systemctl restart ssh\n\
' > /cloud-init/user-data && \
    echo 'instance-id: ubuntu-vm\nlocal-hostname: ubuntu-vm\n' > /cloud-init/meta-data

RUN apt-get update && \
    apt-get install -y xorriso && \
    xorriso -as mkisofs -R -V "cidata" -J -o /cloud-init.iso /cloud-init && \
    apt-get remove -y xorriso && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

RUN echo '#!/bin/bash\n\
qemu-system-x86_64 -enable-kvm -drive file=/ubuntu.img,format=qcow2 -cdrom /cloud-init.iso -m 4096 -smp 2 -device virtio-net,netdev=net0 -netdev user,id=net0,hostfwd=tcp::2222-:22 -vnc 0.0.0.0:0 -nographic &\n\
sleep 5\n\
websockify --web /usr/share/novnc/ 6080 localhost:5900\n\
' > /start-vm.sh && chmod +x /start-vm.sh

EXPOSE 6080 2222 5900

CMD ["/start-vm.sh"]
