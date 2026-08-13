FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Download with multiple mirrors for reliability
RUN echo "Downloading Ubuntu cloud image..." && \
    (wget -q --timeout=30 --tries=3 https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -O /ubuntu.img || \
     wget -q --timeout=30 --tries=3 https://releases.ubuntu.com/22.04/ubuntu-22.04.3-live-server-amd64.iso -O /ubuntu.iso || \
     wget -q --timeout=30 --tries=3 https://cdimage.ubuntu.com/ubuntu-server/jammy/daily-live/current/jammy-live-server-amd64.iso -O /ubuntu.iso) && \
    if [ -f /ubuntu.img ]; then \
        qemu-img resize /ubuntu.img 20G; \
    else \
        qemu-img create -f qcow2 /disk.qcow2 20G && \
        echo "Created blank disk. You'll need to install OS manually."; \
    fi

# Use whatever image we have (cloud img or ISO)
RUN if [ -f /ubuntu.img ]; then \
        echo '#!/bin/bash\n\
qemu-system-x86_64 -enable-kvm \\\n\
    -drive file=/ubuntu.img,format=qcow2 \\\n\
    -m 4096 \\\n\
    -smp 2 \\\n\
    -device virtio-net,netdev=net0 \\\n\
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \\\n\
    -nographic \\\n\
    -serial mon:stdio\n\
' > /start-vm.sh; \
    elif [ -f /ubuntu.iso ]; then \
        echo '#!/bin/bash\n\
qemu-img create -f qcow2 /disk.qcow2 20G\n\
qemu-system-x86_64 -enable-kvm \\\n\
    -cdrom /ubuntu.iso \\\n\
    -drive file=/disk.qcow2,format=qcow2 \\\n\
    -m 4096 \\\n\
    -smp 2 \\\n\
    -device virtio-net,netdev=net0 \\\n\
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \\\n\
    -nographic \\\n\
    -serial mon:stdio\n\
' > /start-vm.sh; \
    else \
        echo '#!/bin/bash\n\
echo "No OS image found. Please install manually."\n\
tail -f /dev/null\n\
' > /start-vm.sh; \
    fi && \
    chmod +x /start-vm.sh

EXPOSE 2222

CMD ["/start-vm.sh"]
