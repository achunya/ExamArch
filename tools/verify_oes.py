#!/usr/bin/env python3
import glob, json, os, re, sys

EXT_ID = "gkihmdkemmjchaccfmibdddlkklfocbn"
POLICY_DIR = "/etc/chromium/policies/managed"
PROFILE = os.environ.get("KIOSK_PROFILE", "/home/kiosk/.config/chromium/Default")
LOC = {1: "INTERNAL", 6: "EXTERNAL_PREF_DOWNLOAD", 7: "EXTERNAL_POLICY_DOWNLOAD", 9: "EXTERNAL_POLICY"}
ok = lambda m: print(f"  [OK]   {m}")
bad = lambda m: print(f"  [FAIL] {m}")
info = lambda m: print(f"  [i]    {m}")

def match(pattern, url):
    m = re.match(r"^(\*|https?)://([^/]*)(/.*)$", pattern)
    u = re.match(r"^(https?)://([^/:]*)(?::\d+)?(/.*)?$", url)
    if not m or not u:
        return False
    sch, host, path = m.groups()
    usch, uhost, upath = u.group(1), u.group(2), u.group(3) or "/"
    if sch not in ("*", usch):
        return False
    if host.startswith("*."):
        if not (uhost == host[2:] or uhost.endswith("." + host[2:])):
            return False
    elif host not in ("*", uhost):
        return False
    return re.match("^" + re.escape(path).replace(r"\*", ".*") + "$", upath) is not None

lms = sys.argv[1] if len(sys.argv) > 1 else "https://lms.astanait.edu.kz/"
pol = {}
print("1. Policy")
for p in sorted(glob.glob(f"{POLICY_DIR}/*.json")):
    try:
        d = json.load(open(p))
    except json.JSONDecodeError as e:
        bad(f"{p}: невалидный JSON ({e}) — Chromium игнорирует весь файл"); continue
    for k in d:
        if k in pol: bad(f"{k} задан в нескольких файлах")
    pol.update(d)
fl = pol.get("ExtensionInstallForcelist", [])
entry = next((e for e in fl if e.startswith(EXT_ID)), None)
if not entry: bad("ID нет в ExtensionInstallForcelist")
elif entry.split(";", 1)[1].startswith("file://"): bad("update URL = file:// — не поддерживается")
else: ok(entry)

print("2. Расширение в профиле")
mans = sorted(glob.glob(f"{PROFILE}/Extensions/{EXT_ID}/*/manifest.json"))
if not mans:
    bad("не скачано — нет сети до clients2.google.com или Chromium ещё не запускался"); sys.exit(1)
man = json.load(open(mans[-1], encoding="utf-8-sig"))
ok(f"{man['name']} v{man['version']}")

print("3. Состояние в Preferences")
for pf in ("Secure Preferences", "Preferences"):
    try:
        s = json.load(open(f"{PROFILE}/{pf}"))["extensions"]["settings"].get(EXT_ID)
    except (OSError, KeyError, json.JSONDecodeError):
        continue
    if s:
        loc = s.get("location")
        (ok if loc == 7 else bad)(f"{pf}: location={loc} ({LOC.get(loc, '?')}), нужно 7")
        (bad if s.get("disable_reasons") else ok)(f"disable_reasons={s.get('disable_reasons', 'нет')}")

print(f"4. Активация на {lms}")
cs = [m for c in man.get("content_scripts", []) for m in c.get("matches", [])]
hit = [m for m in cs if match(m, lms)]
(ok if hit else bad)(f"content_scripts: {hit or 'нет совпадений'}")
info(f"permissions: {man.get('permissions')}")

print("5. URLBlocklist vs страницы расширения")
if "*" in pol.get("URLBlocklist", []) and not any(EXT_ID in a for a in pol.get("URLAllowlist", [])):
    bad("chrome-extension://<id> не в URLAllowlist")
else:
    ok("страницы расширения разрешены")
