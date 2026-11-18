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
    # The compositor (labwc/wayfire) creates the socket but doesn't have
    # WAYLAND_DISPLAY in its own environment, so reading its /proc/*/environ
    # doesn't work. Find the live socket directly instead -- this also
    # works when run over SSH, where WAYLAND_DISPLAY isn't inherited.
    native_wayland_display=$(basename "$(ls -t "$XDG_RUNTIME_DIR"/wayland-[0-9]* 2>/dev/null \
        | grep -v '\.lock$' | head -1)" 2>/dev/null)
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
