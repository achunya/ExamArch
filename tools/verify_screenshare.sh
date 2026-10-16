#!/bin/bash
set -u
U=kiosk
UID_K=$(id -u "$U") || { echo "нет пользователя $U"; exit 1; }
export XDG_RUNTIME_DIR=/run/user/$UID_K
export DBUS_SESSION_BUS_ADDRESS=unix:path=$XDG_RUNTIME_DIR/bus
asu() { runuser -u "$U" -- env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" "$@"; }
ok()  { echo "  [OK]   $*"; }
bad() { echo "  [FAIL] $*"; FAILS=$((FAILS+1)); }
FAILS=0

echo "1. Пакеты"
for p in pipewire wireplumber xdg-desktop-portal xdg-desktop-portal-wlr; do
    pacman -Q "$p" >/dev/null 2>&1 && ok "$p" || bad "$p не установлен"
done

echo "2. Пользовательская сессия kiosk"
[ -S "$XDG_RUNTIME_DIR/bus" ] && ok "user bus" || bad "нет user bus"
for u in pipewire.service wireplumber.service; do
    [ "$(asu systemctl --user is-active $u)" = active ] && ok "$u active" || bad "$u не активен"
done

echo "3. Окружение systemd --user"
ENVOUT=$(asu systemctl --user show-environment)
WD=$(sed -n 's/^WAYLAND_DISPLAY=//p' <<<"$ENVOUT")
for v in WAYLAND_DISPLAY XDG_CURRENT_DESKTOP; do
    grep -q "^$v=" <<<"$ENVOUT" && ok "$(grep "^$v=" <<<"$ENVOUT")" || bad "$v не импортирован"
done

echo "4. Протокол screencopy в cage (главное условие)"
if command -v wayland-info >/dev/null; then
    WI=$(asu env WAYLAND_DISPLAY="$WD" wayland-info 2>/dev/null)
    grep -q zwlr_screencopy_manager_v1 <<<"$WI" && ok "screencopy" || bad "нет zwlr_screencopy_manager_v1"
    grep -q zwp_linux_dmabuf_v1 <<<"$WI" && ok "linux_dmabuf" \
        || bad "нет zwp_linux_dmabuf_v1 — xdpw 0.8 не запустится (pixman-рендерер или нет GPU)"
fi
command -v grim >/dev/null && { asu env WAYLAND_DISPLAY="$WD" grim /tmp/kiosk-shot.png 2>/dev/null \
    && ok "grim снял скриншот /tmp/kiosk-shot.png" || bad "grim не смог снять экран"; }

echo "5. Портал ScreenCast"
VER=$(asu busctl --user get-property org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop \
        org.freedesktop.portal.ScreenCast version 2>&1)
[[ "$VER" == u* ]] && ok "ScreenCast portal: $VER" || bad "ScreenCast portal недоступен: $VER"

echo "6. Конфиг xdpw"
CFG=/home/$U/.config/xdg-desktop-portal-wlr/config
[ -f "$CFG" ] && { ok "$CFG"; sed 's/^/         /' "$CFG"; } || bad "нет $CFG"
grep -q '^output_name=.\+' "$CFG" 2>/dev/null || bad "output_name пустой"

echo "7. Chromium"
CMD=$(pgrep -u "$U" -a -x chromium | head -n1)
if [ -n "$CMD" ]; then
    grep -q -- '--ozone-platform=wayland' <<<"$CMD" && ok "нативный Wayland" || bad "не ozone-wayland"
    grep -q -- '--no-sandbox' <<<"$CMD" && bad "--no-sandbox присутствует!" || ok "sandbox включён"
else
    bad "Chromium под $U не запущен"
fi

echo "8. Логи порталов"
asu journalctl --user -u xdg-desktop-portal -u xdg-desktop-portal-wlr -n 15 --no-pager 2>/dev/null | sed 's/^/         /'
echo; [ "$FAILS" -eq 0 ] && echo "Итог: всё зелёное" || echo "Итог: $FAILS проблем(ы)"
