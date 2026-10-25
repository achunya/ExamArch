#!/bin/bash
set -u
ALLOWFILE=/etc/examarch/allowlist.conf

echo "1. State"
nft list table inet examarch >/dev/null 2>&1 && echo "  [OK]   nftable examarch is loaded" || echo "  [FAIL] nftable is not loaded"
dnsmasq --version | grep -qw nftset && echo "  [OK]   dnsmasq is built with nftset" || echo "  [FAIL] dnsmasq without nftset"
systemctl is-active -q dnsmasq && echo "  [OK]   dnsmasq is working" || echo "  [FAIL] dnsmasq is not working"
grep -q '^nameserver 127.0.0.1' /etc/resolv.conf && echo "  [OK]   resolv.conf -> 127.0.0.1" || echo "  [FAIL] resolv.conf does not point to dnsmasq"
echo "  [i] adderesses in allow4: $(nft -j list set inet examarch allow4 2>/dev/null | grep -o '"elem"' | wc -l)"

ALLOW=$(sed -n 's|^nftset=/\(.*\)/4#.*|\1|p' "$ALLOWFILE" | tr '/' '\n')
allowed() { for a in $ALLOW; do [[ $1 == "$a" || $1 == *".$a" ]] && return 0; done; return 1; }

LOG=$(journalctl -b -u dnsmasq --no-pager -o cat)

echo
echo "2. Requested domens, but not in the allowlist"
sed -n 's/^query\[A\] \([^ ]*\) from.*/\1/p' <<<"$LOG" | sort -u | while read -r d; do
    allowed "$d" || echo "  $d"
done

echo
echo "3. Connections that were banned in prod(amount, IP, Protocol, Port, Name)"
journalctl -b -k --no-pager -o cat | grep 'EXAMARCH-OUT' \
  | sed -n 's/.*DST=\([0-9.]*\).*PROTO=\([A-Z]*\).*DPT=\([0-9]*\).*/\1 \2 \3/p' \
  | sort | uniq -c | sort -rn | head -40 | while read -r n ip proto port; do
        name=$(grep -F " is $ip" <<<"$LOG" | sed -n 's/^reply \([^ ]*\) is .*/\1/p' | sort -u | head -1)
        printf "  %5s  %-15s %-4s %-5s %s\n" "$n" "$ip" "$proto" "$port" "${name:-<no DNS name: candidate to static4>}"
    done

echo
echo "What to do: domens from p.2, which are required for LMS/OES, add to $ALLOWFILE;"
echo "IP without DNS name p.3 (usually mediaservices WebRTC) — subnet in set static4 in /etc/nftables.conf."
