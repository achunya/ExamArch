#!/usr/bin/env bash
# Error handler
set -eu

useradd -m -p "" -G "video,input,seat" -s /usr/bin/zsh kiosk
passwd -l kiosk # Blocking the user
