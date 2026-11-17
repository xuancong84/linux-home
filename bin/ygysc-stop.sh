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
