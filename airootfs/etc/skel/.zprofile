if [[ -z $DISPLAY ]] && [[ $(tty) == "/dev/tty1" ]]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 0700 "$XDG_RUNTIME_DIR"

    export WLR_NO_HARDWARE_CURSORS=1
    export WLR_RENDERER=pixman

    export XKB_CONFIG_ROOT="/etc/xkb:/usr/share/X11/xkb"
    export XKB_DEFAULT_LAYOUT="kiosk_nokeys"

    command -v nm-online >/dev/null 2>&1 && nm-online -q -t 30
    
    while true; do
        dbus-run-session cage -- chromium \
            --ozone-platform=wayland \
            --disable-dev-shm-usage \
            --disable-gpu \
            --kiosk \
            --no-first-run \
            --no-default-browser-check \
            "https://lms.astanait.edu.kz"
    done
fi
