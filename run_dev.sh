#!/usr/bin/env bash
ISO="$(ls -t ~/iso_out/examarch-${1:-dev}-*.iso | head -n1)"
exec qemu-system-x86_64 \
    -enable-kvm -cpu host -smp 4 -m 4G \
    -cdrom "$ISO" -boot d \
    -device virtio-vga-gl -display sdl,gl=on \
    -nic user,model=virtio-net-pci \
    -serial mon:stdio
