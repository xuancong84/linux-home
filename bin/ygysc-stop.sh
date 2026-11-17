#!/bin/bash
# Stops the fullscreen Waydroid UI started by ygysc-start.sh.
#
# `waydroid session stop` runs `lxc-stop -k` under the hood, which force
# -kills the container's init immediately -- no SIGPWR, no Android
# shutdown broadcast, so apps get no onPause()/onStop() and can't save
# state (e.g. playback position). To avoid that, send a HOME keyevent
# first, same as a user pressing Home, which does reliably trigger the
# foreground app's onPause()/onStop() through the normal lifecycle, and
# give it a moment to finish before the hard stop.
set -u
LOGTAG=ygysc-stop
log() { echo "[$LOGTAG] $*"; }

if waydroid status 2>/dev/null | grep -q "Session:[[:space:]]*RUNNING"; then
    log "backgrounding the foreground app (HOME) so it can save state"
    sudo waydroid shell -- input keyevent KEYCODE_HOME >/dev/null 2>&1
    sleep 2
fi

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
