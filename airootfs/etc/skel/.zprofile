if [[ -z $WAYLAND_DISPLAY ]] && [[ $(tty) == "/dev/tty1" ]]; then
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

    export WLR_NO_HARDWARE_CURSORS=1

    VARIANT="$(cat /etc/kiosk-variant 2>/dev/null || echo prod)"
    CAGE_FLAGS=()
    export XKB_CONFIG_ROOT="/etc/xkb:/usr/share/X11/xkb"
    if [[ $VARIANT == dev ]]; then
        export XKB_DEFAULT_LAYOUT="us"
        CAGE_FLAGS=(-s)
    else
        export XKB_DEFAULT_LAYOUT="kiosk_nokeys"
    fi

    command -v nm-online >/dev/null 2>&1 && nm-online -q -t 30

    while true; do
        cage "${CAGE_FLAGS[@]}" -- /usr/local/bin/kiosk-session
        sleep 1
    done
fi
