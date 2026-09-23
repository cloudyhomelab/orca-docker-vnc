# Pinned by digest so a rebuild gets the same base; Dependabot moves the digest when the tag does.
FROM debian:trixie-slim@sha256:a99cfc517144bc59b1978475ec53b46ecabec7e43635402ee5b77cc54cd1b20a

# Orca is an Electron app shipped as a glibc .deb; Alpine/musl cannot run it.
# No default: docker-bake.hcl is the pin.
ARG ORCA_VERSION

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      cage wayvnc wlr-randr novnc websockify fonts-dejavu-core ca-certificates curl git \
      libgbm1 libasound2t64 \
 && curl -fsSL -o /tmp/orca.deb \
      "https://github.com/stablyai/orca/releases/download/v${ORCA_VERSION}/orca-ide_${ORCA_VERSION}_$(dpkg --print-architecture).deb" \
 && apt-get install -y --no-install-recommends /tmp/orca.deb \
 && rm -f /tmp/orca.deb \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --create-home --uid 1000 orca \
 && install -d -m 700 -o orca -g orca /run/user/1000

COPY --chmod=755 orca-kiosk.sh /usr/local/bin/orca-kiosk
# noVNC ships no index page; this one opens the viewer with autoconnect and remote resize.
COPY novnc-index.html /usr/share/novnc/index.html

USER orca
ENV XDG_RUNTIME_DIR=/run/user/1000 \
    WLR_BACKENDS=headless \
    WLR_LIBINPUT_NO_DEVICES=1 \
    WLR_RENDERER=pixman \
    ORCA_RESOLUTION=1920x1080

EXPOSE 5900 6080
# cage runs one client fullscreen and exits when it exits; -d suppresses client-side decorations.
CMD ["cage", "-d", "--", "orca-kiosk"]
