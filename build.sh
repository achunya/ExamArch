#!/usr/bin/env bash
set -euo pipefail

VARIANT="${1:-prod}"
[[ $VARIANT == prod || $VARIANT == dev ]] || { echo "variant: prod|dev"; exit 1; }

SRC="$(cd "$(dirname "$0")" && pwd)"
OUT="$HOME/iso_out"
WORK="/tmp/archiso-tmp-$VARIANT"
PROFILE="$(mktemp -d /tmp/examarch-profile-XXXX)"
trap 'sudo rm -rf "$PROFILE"' EXIT

cp -a "$SRC/." "$PROFILE/"
rm -rf "$PROFILE/.git" "$PROFILE/pkg_cache"
echo "$VARIANT" > "$PROFILE/airootfs/etc/kiosk-variant"

if [[ $VARIANT == dev ]]; then
    cat "$SRC/packages.dev.x86_64" >> "$PROFILE/packages.x86_64"

    printf '[Login]\nNAutoVTs=2\n' > "$PROFILE/airootfs/etc/systemd/logind.conf.d/99-dev-vts.conf"
    python3 - "$PROFILE/airootfs/etc/chromium/policies/managed/url_restriction.json" <<'EOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["URLAllowlist"] += ["chrome://policy", "chrome://extensions",
                      "chrome://webrtc-internals", "https://webrtc.github.io"]
json.dump(d, open(p, "w"), indent=2)
EOF

    install -Dm 644 "$PROFILE/airootfs/etc/nftables.conf" "$PROFILE/airootfs/etc/examarch/nftables.enforce.conf"
    sed -i 's|# EXAMARCH-VERDICT|accept|' "$PROFILE/airootfs/etc/nftables.conf"
    echo "log-queries" >> "$PROFILE/airootfs/etc/dnsmasq.conf"
    for f in "$SRC"/tools/*; do
        n="$(basename "$f")"
        install -m 755 "$f" "$PROFILE/airootfs/usr/local/bin/$n"
        sed -i "s|^)\$|  [\"/usr/local/bin/$n\"]=\"0:0:755\"\n)|" "$PROFILE/profiledef.sh"
    done
    SG="$PROFILE/airootfs/etc/systemd/system"
    mkdir -p "$SG/serial-getty@ttyS0.service.d" "$SG/getty.target.wants"
    printf '%s\n' '[Service]' 'ExecStart=' \
        'ExecStart=-/sbin/agetty --autologin root --keep-baud 115200,57600,38400,9600 %I $TERM' \
        > "$SG/serial-getty@ttyS0.service.d/autologin.conf"
    ln -sf /usr/lib/systemd/system/serial-getty@.service "$SG/getty.target.wants/serial-getty@ttyS0.service"
fi

sed -i "s|^CacheDir.*|CacheDir = $SRC/pkg_cache|" "$PROFILE/pacman.conf"
mkdir -p "$SRC/pkg_cache" "$OUT"

sudo rm -rf "$WORK"
sudo env KIOSK_VARIANT="$VARIANT" mkarchiso -v -r -w "$WORK" -o "$OUT" "$PROFILE" 2>&1 | tee "$SRC/build.log"
sudo chown -R "$(id -un):$(id -gn)" "$OUT"

grep -q "Running customize_airootfs.sh" "$SRC/build.log" \
    && echo ">> customize_airootfs.sh выполнился" \
    || echo "!! customize_airootfs.sh НЕ выполнился — смотри build.log"
ls -lh "$OUT"/examarch-"$VARIANT"-*.iso
