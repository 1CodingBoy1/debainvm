FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    wget \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -O /ubuntu.img && \
    qemu-img resize /ubuntu.img 20G

RUN echo '#!/bin/bash\n\
# Start VM with serial console (no VNC)\n\
qemu-system-x86_64 -enable-kvm \\\n\
    -drive file=/ubuntu.img,format=qcow2 \\\n\
    -m 4096 \\\n\
    -smp 2 \\\n\
    -device virtio-net,netdev=net0 \\\n\
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \\\n\
    -nographic \\\n\
    -serial mon:stdio\n\
' > /start-vm.sh && chmod +x /start-vm.sh

EXPOSE 2222

CMD ["/start-vm.sh"]
