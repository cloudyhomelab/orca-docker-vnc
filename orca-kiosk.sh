#!/bin/sh
# Runs as cage's single client. cage exits when this process exits, so Orca is exec'd last.
set -eu

# cage has no output config; the headless output defaults to 1280x720.
wlr-randr --output HEADLESS-1 --custom-mode "$ORCA_RESOLUTION"

# Git identity from compose; unset leaves what the home volume already holds.
[ -z "${GIT_USER_NAME:-}" ] || git config --global user.name "$GIT_USER_NAME"
[ -z "${GIT_USER_EMAIL:-}" ] || git config --global user.email "$GIT_USER_EMAIL"

wayvnc 0.0.0.0 5900 &
# noVNC over HTTP: websockify serves the viewer and bridges WebSocket to the VNC port.
websockify --web /usr/share/novnc 6080 localhost:5900 &

# /usr/bin/orca-ide is the CLI shim (Node mode, no window); the GUI binary lives in /opt/Orca.
# --no-sandbox:      Chromium's sandbox needs user namespaces or a SUID helper, both unavailable
#                    under Docker's default seccomp/capability profile.
# --ozone-platform:  no Xwayland in the image, so Electron must speak Wayland directly.
# --disable-gpu:     no DRM device; avoids a GPU-process crash loop (WebGL off, terminals use DOM renderer).
# --password-store:  no Secret Service on D-Bus in the container.
exec /opt/Orca/orca-ide \
  --no-sandbox \
  --ozone-platform=wayland \
  --disable-gpu \
  --password-store=basic
