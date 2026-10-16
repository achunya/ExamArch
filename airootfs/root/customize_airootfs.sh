#!/usr/bin/env bash
set -eu

useradd -m -p "" -G video -s /usr/bin/zsh kiosk
passwd -l kiosk

systemctl --global enable pipewire.socket pipewire-pulse.socket wireplumber.service

if [[ "$(cat /etc/kiosk-variant 2>/dev/null)" != "dev" ]]; then
    passwd -l root
fi
