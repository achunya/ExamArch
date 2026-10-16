# ExamArch

My diploma project at Astana IT University: a live USB system for taking exams on the LMS, built on Arch Linux.

The idea is simple. Instead of a lockdown browser running on the student's own OS, the student boots from a USB stick into a minimal system that only runs Chromium with the LMS. There's no desktop, no other apps and no console to escape to. On top of that I'm working on a small ML part that looks at mouse movement and tries to tell a real person from a script or remote control.

Thesis title: *Development of a Secure Live-Boot Examination Environment Based on Arch Linux with ML-Based Detection of Lockdown Bypass Attempts*. Supervisor: Baurzhan Yessingeldinov.

## How it works

- **archiso** builds the live image; everything runs from RAM
- **cage** (a tiny Wayland compositor) runs exactly one app: Chromium in kiosk mode
- **Chromium policies** allow only the LMS, Microsoft login and OES; DevTools and incognito are off
- **OES** (the proctoring extension the university uses) is force-installed through policy
- **Screen sharing** works through PipeWire and xdg-desktop-portal-wlr, so OES can capture the screen
- The session runs as an unprivileged `kiosk` user with the Chromium sandbox on. If Chromium crashes, the session just restarts — you never land in a shell

## Building and running

You need Arch Linux with `archiso` and `qemu-full`.

```bash
./build.sh prod     # the actual exam image
./build.sh dev      # debug image
./run_dev.sh        # boot the latest dev image in QEMU
```

The dev image is the same system plus a few things that make debugging possible: a normal keyboard layout, a second console, a root shell on the serial port, some diagnostic pages in Chromium and two check scripts (`verify_oes.py`, `verify_screenshare.sh`). None of that ends up in the prod image.

In QEMU, the terminal becomes the guest's serial console. `Ctrl+A` then `C` switches to the QEMU monitor and back, `Ctrl+A` then `X` quits.

To use a different LMS, change `LMS_URL` in `airootfs/usr/local/bin/kiosk-session` and the allowlist in `airootfs/etc/chromium/policies/managed/url_restriction.json`.

## What works so far

- Live image with cage + Chromium kiosk
- Unprivileged user, sandbox enabled
- URL allowlist, no DevTools, no incognito
- OES installs and activates on the LMS
- Screen sharing (tested with `getDisplayMedia`)
- Separate dev and prod builds from one profile

Still needs to be checked on the prod image: the keyboard lockdown (Ctrl, Alt, Tab), disabled console switching and SysRq, and the locked root account.

## Things that broke along the way

A short log of real problems I hit, mostly so I don't forget them:

- The autostart loop originally dropped to a root shell if Chromium crashed
- At first everything ran as root with `--no-sandbox`
- `customize_airootfs.sh` silently didn't run (missing permissions, then a typo in the file name)
- OES was never installed because the policy pointed at a local `file://` CRX, which Chromium ignores
- `dbus-run-session` put the browser on its own D-Bus, so PipeWire and the screen sharing portal were invisible to it
- A dev config file lost to the prod one because of alphabetical ordering of systemd drop-ins
- Screen sharing failed because I'd forced the software renderer (pixman). xdg-desktop-portal-wlr needs dmabuf, which pixman doesn't provide — the error message doesn't say that, I found it in the source

## TODO

**System**
- Run the full lockdown test list on the prod image (key combos, `chrome://` / `file://` URLs, a second keyboard, Chromium crash, "Stop sharing", second monitor)
- Add an nftables firewall as a second layer behind the Chromium policy
- Speed up builds (currently ~12 min)

**Data**
- Mouse/keyboard telemetry as a root service the student session can't touch
- Data partition on the USB stick
- Practice quiz in Moodle, consent form
- Collect sessions from about 50 volunteers on one laptop with one USB mouse

**ML**
- Window-based mouse features (speed, curvature, pauses, clicks)
- Isolation Forest trained on normal sessions only
- Evaluate per participant, with one attack type held out
- Compare with One-Class SVM and LOF

## Limitations

- Screen sharing needs a real GPU (any Intel or AMD integrated graphics is fine)
- It doesn't deal with phones, notes or someone sitting next to you — that's what OES camera proctoring is for
- All data comes from one laptop, so I haven't tested how well it carries over to other hardware

## Privacy

Telemetry only records mouse and keyboard events, never screen content. Participants get IDs instead of names and sign a consent form. The dataset is not in this repo.
