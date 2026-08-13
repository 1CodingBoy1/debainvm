FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Use the correct, currently available Ubuntu 22.04.5 LTS ISO
RUN wget -q --progress=bar:force https://releases.ubuntu.com/22.04/ubuntu-22.04.5-live-server-amd64.iso -O /ubuntu.iso && \
    qemu-img create -f qcow2 /disk.qcow2 20G

RUN echo '#!/bin/bash\n\
echo "Starting Ubuntu Server VM with terminal access..."\n\
echo "You will need to complete the installation process."\n\
echo "Set a username and password when prompted."\n\
echo ""\n\
qemu-system-x86_64 -enable-kvm \\\n\
    -cdrom /ubuntu.iso \\\n\
    -drive file=/disk.qcow2,format=qcow2 \\\n\
    -m 4096 \\\n\
    -smp 2 \\\n\
    -device virtio-net,netdev=net0 \\\n\
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \\\n\
    -nographic \\\n\
    -serial mon:stdio\n\
' > /start-vm.sh && chmod +x /start-vm.sh

EXPOSE 2222

CMD ["/start-vm.sh"]
