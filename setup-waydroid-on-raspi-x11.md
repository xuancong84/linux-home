# Setting up Waydroid on a Raspberry Pi while keeping the X11 desktop

Waydroid only speaks Wayland on the host side — there's no X11-native mode.
The two ways to reconcile that with a Pi running a normal X11 desktop
(LXDE-pi-x) are: (a) switch the whole desktop session to a Wayland
compositor (labwc/wayfire), or (b) run a small nested Wayland compositor
just for Waydroid, leaving the main desktop on X11. This doc covers (b):
**Weston, nested via its X11 backend**, which opens as an ordinary (or
fullscreen) window/output inside the existing X11 session.

Tested on: Raspberry Pi 5, Raspberry Pi OS Bookworm (Debian 12), kernel
`6.12.115+rpt-rpi-v8`, Waydroid `1.6.3`, Weston `10.0.1`.

## Overview of the steps

1. Install Weston.
2. Fix two Waydroid/LXC packaging bugs that block the Android container
   from booting at all (cgroup delegation + cgroup mount mode) — these
   are unrelated to X11/Weston and would bite any Waydroid setup on a
   modern cgroup-v2-only host.
3. Enable the kernel's PSI feature — required by Android's `lmkd`, off by
   default on this kernel.
4. Reboot, then install the APK.
5. Launch Weston (fullscreen, X11 backend) + the Waydroid session.
6. (Optional, if you want audio) fix PulseAudio auth + buffering so
   Android's audio HAL can actually talk to it.

Steps 2–3 need a reboot to take effect, so do them together before
rebooting once.

## 1. Install Weston

```sh
sudo apt-get install -y weston
```

## 2. Fix Waydroid's cgroup setup (needed regardless of X11/Wayland)

Without this, the Android container boots, then `lmkd` (a "critical"
Android init service) crashes repeatedly and the container self-reboots
in a loop — it never actually comes up. Two separate bugs stack here:

### 2a. `waydroid-container.service` is missing cgroup delegation

Add a systemd drop-in (don't edit the packaged unit file directly, so
package upgrades don't clobber it):

```sh
sudo mkdir -p /etc/systemd/system/waydroid-container.service.d
sudo tee /etc/systemd/system/waydroid-container.service.d/override.conf >/dev/null <<'EOF'
[Service]
Delegate=yes
EOF
sudo systemctl daemon-reload
sudo systemctl restart waydroid-container.service
```

### 2b. Waydroid's own LXC template mounts cgroups fully read-only

`/usr/lib/waydroid/data/configs/config_base` ships with:

```
lxc.mount.auto = cgroup:ro sys:ro proc
```

`cgroup:ro` makes *even the container's own* cgroup subtree read-only, so
`lmkd` can't create its per-process cgroup directories
(`Failed to make and chown /sys/fs/cgroup/uid_NNNN: Read-only file
system`). Fix it to `cgroup:mixed` (writable for the container's own
cgroup, read-only for everything above it — the standard safe LXC mode;
the container already runs with `sys_admin` in `lxc.cap.keep`, so it's
entitled to this):

```sh
sudo sed -i 's/lxc.mount.auto = cgroup:ro sys:ro proc/lxc.mount.auto = cgroup:mixed sys:ro proc/' \
    /usr/lib/waydroid/data/configs/config_base
# also patch the already-generated live config so it applies without a full re-init:
sudo sed -i 's/lxc.mount.auto = cgroup:ro sys:ro proc/lxc.mount.auto = cgroup:mixed sys:ro proc/' \
    /var/lib/waydroid/lxc/waydroid/config
```

## 3. Enable PSI in the kernel

Android's `lmkd` (post-Android-10 implementation) requires
`/proc/pressure/memory` to exist. Check:

```sh
cat /proc/pressure/memory   # "No such file or directory" means it's off
zcat /proc/config.gz | grep CONFIG_PSI   # or grep your /boot/config-$(uname -r)
```

If you see `CONFIG_PSI=y` + `CONFIG_PSI_DEFAULT_DISABLED=y`, PSI is
compiled in but off by default and can only be turned on via a boot
parameter — there's no runtime sysctl for it. Add `psi=1` to
`/boot/firmware/cmdline.txt` (single line, just append with a space):

```sh
sudo sed -i 's/$/ psi=1/' /boot/firmware/cmdline.txt
```

## 4. Reboot, then verify + install the APK

```sh
sudo reboot
# after it comes back up:
cat /proc/pressure/memory      # should now print real numbers
```

Waydroid's container service starts automatically via systemd
(`waydroid-container.service`). Install your APK with the container
running (doesn't need the Wayland session up yet):

```sh
waydroid app install ~/path/to/your.apk
waydroid app list   # confirm it shows up
```

## 5. Launching: nested Weston + Waydroid session

Running GUI tools against the Pi's real local X display (`:0`) from an
SSH session (no inherited `DISPLAY`/`XAUTHORITY`) needs the lightdm auth
cookie pulled into your own session first:

```sh
cookie=$(sudo xauth -f /var/run/lightdm/root/:0 list 2>/dev/null | head -1)
xauth add $cookie
```

Then start Weston fullscreen, nested via its X11 backend, and point
Waydroid at the Wayland socket it creates:

```sh
DISPLAY=:0 weston --backend=x11-backend.so \
    --width=1920 --height=1080 --fullscreen \
    --socket=waydroid-wayland &

export WAYLAND_DISPLAY=waydroid-wayland
waydroid session start &
# wait for sys.boot_completed=1 (see script below for a real poll loop),
# THEN:
waydroid show-full-ui &
```

Notes:
- `--fullscreen` is the key flag — without it you get a normal
  X11 window, and the window manager's own "maximize" does **not**
  resize Weston's internal output, so the Android content stays boxed in
  at its original size even if you maximize the window frame. With
  `--fullscreen`, Weston creates a borderless window matching its
  `--width`/`--height`, so content genuinely fills the screen.
- `waydroid show-full-ui` renders the Android UI into whatever
  `WAYLAND_DISPLAY` is currently exported — it's what actually puts
  pixels in the Weston window. It's a short-lived trigger, not a
  persistent process.
- Checking `getprop sys.boot_completed` (not just `waydroid status`'s "IP
  address" field) is the reliable way to know the container has actually
  finished booting — IP shows up well before the package manager and
  activity manager are ready, so launching an app too early fails with
  "Activity class does not exist" even though the package is installed.

A ready-to-use pair of scripts that wrap all of this (including
detecting whether the desktop is on X11 or native Wayland, so they skip
the nested Weston step when it's not needed) live at `~/bin/ygysc-start.sh`
and `~/bin/ygysc-stop.sh` — full listing in the appendix below.

## 6. Audio (optional but usually wanted)

Waydroid bind-mounts the host's PulseAudio socket into the container so
Android's audio HAL can play through it. Two separate problems commonly
block it from actually working, and *weston/Wayland have nothing to do
with either* — audio never goes through the compositor.

### 6a. PulseAudio rejects the container's connection (silent failure)

The container has no PulseAudio auth cookie (separate mount/user
namespace), and by default `module-native-protocol-unix` requires one.
Without `auth-anonymous=1`, the Android audio HAL's connection attempts
are silently rejected — nothing ever reaches PulseAudio, with no error
visible from the Android side.

Edit `/etc/pulse/default.pa`:

```diff
-load-module module-native-protocol-unix
+load-module module-native-protocol-unix auth-anonymous=1
```

Still safe: access is still gated by the unix socket file's own
permissions, this doesn't expose anything over the network.

### 6b. Default PulseAudio buffering is too tight for Android's mixer

Even once the connection works, Android's `AudioFlinger` is far more
timing-strict than typical desktop apps (VLC etc. tolerate much more
buffering). Symptom: real audio data reaches PulseAudio (a sink-input
genuinely exists, non-silent), but logcat is full of:

```
AudioFlinger: BUFFER TIMEOUT: remove(NN) from active list
AudioTrack: restartIfDisabled: releaseBuffer() track disabled due to
            previous underrun, restarting
```

...and `pactl subscribe` shows a *new* sink-input being created and
destroyed every ~10ms in a tight retry loop — so no sound ever actually
plays, for anything (videos, touch sounds, ringtone previews). This
correlates with a minor vc4 HDMI ALSA driver quirk also visible in
`dmesg`: `ALSA woke us up to write new data to the device, but there was
actually nothing to write... bug in ALSA driver 'vc4'`.

Fix: give PulseAudio more buffering headroom in `/etc/pulse/daemon.conf`:

```diff
-; default-fragments = 4
-default-fragment-size-msec = 15
+default-fragments = 8
+default-fragment-size-msec = 25
```

After either change: `systemctl --user restart pulseaudio.service`, then
restart the Waydroid session so its audio HAL reconnects fresh
(`waydroid session stop` / `start` again).

Sanity check that it's actually working, without needing to listen:

```sh
# find the sink-input id
pactl list short sink-inputs
# watch for churn (should settle to 0 new/remove events within a few
# seconds of an app starting — some initial negotiation burst is normal)
timeout 3 pactl subscribe | grep -c "new' on sink-input"
```

### 6c. If you use RealVNC Server for remote access

RealVNC Server's own "audio redirect" feature (captures the default
sink's monitor and streams it to the Viewer) connects to PulseAudio too,
and its connection **does not reliably auto-recover** if PulseAudio gets
restarted out from under it (which both 6a and 6b require). Symptom:
server-side audio is confirmed fine (`pactl list clients` shows your
Android audio thread, real non-silent data), but still silence in the
VNC Viewer — because `vncserver-x11-core` quietly dropped off PulseAudio's
client list and never reconnected.

Fix: `sudo systemctl restart vncserver-x11-serviced.service` (this will
briefly drop your current VNC connection — reconnect after).

## Appendix: launcher scripts

`~/bin/ygysc-start.sh`:

```sh
#!/bin/bash
# Starts Waydroid full-screen on the Pi's local desktop and launches
# 月光影视仓 (com.mygysc). Safe to re-run: skips any piece that's already
# running.
#
# Works under either desktop session type:
#   - X11 (e.g. LXDE-pi-x): nests a fullscreen Weston (X11 backend) to get
#     a Wayland socket for Waydroid, same as before.
#   - Native Wayland (e.g. LXDE-pi-labwc, LXDE-pi-wayfire): talks directly
#     to the already-running compositor, no nested Weston needed.
set -u

PKG=com.mygysc
ACTIVITY=com.github.tvbox.osc.ui.activity.HomeActivity
LOGTAG=ygysc-start

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

log() { echo "[$LOGTAG] $*"; }

# Find the seat0 (physical display) session's type: x11 or wayland. Falls
# back to x11 if it can't be determined.
SESSION_TYPE=x11
for s in $(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}'); do
    seat=$(loginctl show-session "$s" -p Seat --value 2>/dev/null)
    if [ "$seat" = "seat0" ]; then
        t=$(loginctl show-session "$s" -p Type --value 2>/dev/null)
        [ -n "$t" ] && SESSION_TYPE="$t"
        break
    fi
done

if [ "$SESSION_TYPE" = "wayland" ]; then
    log "native Wayland session detected, skipping nested Weston"
    comp_pid=$(pgrep -x labwc 2>/dev/null || pgrep -x wayfire 2>/dev/null || true)
    native_wayland_display=""
    if [ -n "$comp_pid" ]; then
        native_wayland_display=$(tr '\0' '\n' <"/proc/$comp_pid/environ" 2>/dev/null \
            | awk -F= '$1=="WAYLAND_DISPLAY"{print $2; exit}')
    fi
    WAYLAND_SOCK="${native_wayland_display:-wayland-0}"
    log "using native compositor's Wayland display: $WAYLAND_SOCK"
else
    log "X11 session detected, using nested fullscreen Weston"
    WAYLAND_SOCK=waydroid-wayland

    # Always target the Pi's real local desktop display.
    export DISPLAY=:0

    # Make sure we can talk to the local X display (needed when run over
    # SSH rather than from a terminal inside the desktop session).
    if ! DISPLAY="$DISPLAY" xdpyinfo >/dev/null 2>&1; then
        cookie=$(sudo xauth -f "/var/run/lightdm/root/$DISPLAY" list 2>/dev/null | head -1)
        if [ -n "$cookie" ]; then
            xauth add $cookie
        fi
    fi

    read -r SCREEN_W SCREEN_H <<<"$(DISPLAY="$DISPLAY" xrandr 2>/dev/null | awk -F'current ' '/current/{split($2,a,",");gsub(/ /,"",a[1]);gsub(/x/," ",a[1]);print a[1];exit}')"
    SCREEN_W="${SCREEN_W:-1920}"
    SCREEN_H="${SCREEN_H:-1080}"

    if [ ! -S "$XDG_RUNTIME_DIR/$WAYLAND_SOCK" ]; then
        log "starting weston fullscreen (${SCREEN_W}x${SCREEN_H})"
        DISPLAY="$DISPLAY" weston --backend=x11-backend.so \
            --width="$SCREEN_W" --height="$SCREEN_H" --fullscreen \
            --socket="$WAYLAND_SOCK" >/tmp/ygysc-weston.log 2>&1 &
        for i in $(seq 1 30); do
            [ -S "$XDG_RUNTIME_DIR/$WAYLAND_SOCK" ] && break
            sleep 0.5
        done
    else
        log "weston already running, reusing it"
    fi
fi

export WAYLAND_DISPLAY="$WAYLAND_SOCK"

if ! waydroid status 2>/dev/null | grep -q "Session:[[:space:]]*RUNNING"; then
    log "starting waydroid session"
    waydroid session start >/tmp/ygysc-session.log 2>&1 &
else
    log "waydroid session already running"
fi

log "waiting for the android container to finish booting"
for i in $(seq 1 60); do
    booted=$(sudo waydroid shell -- getprop sys.boot_completed 2>/dev/null | tr -d '[:space:]')
    [ "$booted" = "1" ] && { log "container fully booted"; break; }
    sleep 1
done

waydroid show-full-ui >/tmp/ygysc-ui.log 2>&1 &
sleep 2

log "launching $PKG"
for i in $(seq 1 15); do
    out=$(sudo waydroid shell -- am start -n "$PKG/$ACTIVITY" 2>&1)
    echo "$out"
    echo "$out" | grep -q "Error" || break
    sleep 1
done
```

`~/bin/ygysc-stop.sh`:

```sh
#!/bin/bash
# Stops the fullscreen Waydroid UI started by ygysc-start.sh. The Waydroid
# container itself is left running (managed by systemd) so the next start
# is fast; only the on-screen session/compositor is torn down.
set -u
LOGTAG=ygysc-stop
log() { echo "[$LOGTAG] $*"; }

log "stopping waydroid session"
waydroid session stop >/dev/null 2>&1

# Only closes anything if ygysc-start.sh actually started a nested Weston
# (X11 session case); a no-op on native Wayland, where there's nothing to
# close here.
if pgrep -f "weston --backend=x11-backend.so .*--socket=waydroid-wayland" >/dev/null 2>&1; then
    log "closing nested weston"
    pkill -f "weston --backend=x11-backend.so .*--socket=waydroid-wayland" 2>/dev/null
fi

log "done"
```

(Both reference the specific package `com.mygysc` / activity
`com.github.tvbox.osc.ui.activity.HomeActivity` — swap those two
variables for a different app. Find an installed app's launcher activity
with `sudo waydroid shell -- cmd package resolve-activity --brief <pkg>`.)

## Appendix: unrelated pitfall hit while rebooting for this

Not a Waydroid issue, but worth knowing about since steps 3/4 above
require a reboot: if `/etc/profile.d/*.sh` contains bash-only syntax
(`[[ ]]`, `function foo {}`, bare `local`), it can silently sit there for
months without problems — right up until the next time `/etc/X11/Xsession`
sources it via `/bin/sh` (dash) during a *fresh* graphical login, which
dash chokes on, aborting the entire session (autologin and manual login
both loop back to the greeter). If a reboot ever leaves you unable to log
into the desktop at all, check `~/.xsession-errors` for shell syntax
errors, and guard the offending file like this (same idiom Debian's own
`/etc/profile.d/vte-2.91.sh` already uses):

```sh
# at the very top of the file, before any bash-only syntax
if [ -z "$BASH_VERSION" ]; then
    return 0 2>/dev/null || exit 0
fi
```
