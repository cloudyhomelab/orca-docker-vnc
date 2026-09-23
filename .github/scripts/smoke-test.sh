#!/usr/bin/env bash
#
# Runs the image the bake target built the way compose runs it and checks that
# the whole stack comes up: cage starts, wayvnc answers with an RFB banner,
# websockify serves the noVNC page, and Orca is still running a little later.
# A build proves the layers assemble; this proves Electron actually starts
# under the kiosk before the image is published.
#
# Run from the repository root after a bake that left the image in the local
# docker daemon: a plain `docker buildx bake`, or one with --load.
#
#   smoke-test.sh [target]

set -euo pipefail

BAKE_FILE="${BAKE_FILE:-docker-bake.hcl}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/stdout}"
TARGET="${1:-orca}"
# Electron on an emulated or cold runner takes a while; the test only fails on
# a container that exited or a stack that never answers.
TIMEOUT="${SMOKE_TIMEOUT:-120}"
# How long Orca must stay up after the stack answers, to catch a crash on first paint.
SETTLE="${SMOKE_SETTLE:-15}"

fail() {
  echo "smoke-test: $*" >&2
  exit 1
}

[[ -f ${BAKE_FILE} ]] || fail "no ${BAKE_FILE} here; run this from the repository root"

# Looked up through bake rather than assembled from REGISTRY and NAMESPACE here,
# so what runs is exactly what the build tagged.
image=$(docker buildx bake --file "${BAKE_FILE}" --progress=quiet --print \
  | jq -er --arg target "${TARGET}" '.target[$target].tags[0]') \
  || fail "no target '${TARGET}' in ${BAKE_FILE}"

echo "smoke-test: ${TARGET} - ${image}" >&2

cid=""
cleanup() {
  [[ -n ${cid} ]] || return 0
  echo "smoke-test: container log" >&2
  docker logs "${cid}" >&2 || true
  docker rm -f "${cid}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# --pull never, because the tag is the one the published image carries too:
# were the build not loaded, docker run would fetch that from the registry and
# pass the test against the wrong image. init and shm-size mirror compose.yaml.
cid=$(docker run -d --pull never --init --shm-size 1g \
  -e GIT_USER_NAME=smoke -e GIT_USER_EMAIL=smoke@example.com \
  -p 127.0.0.1::6080 -p 127.0.0.1::5900 "${image}")

running() {
  [[ $(docker inspect -f '{{.State.Running}}' "${cid}") == true ]]
}

web=$(docker port "${cid}" 6080/tcp | head -n1)
vnc=$(docker port "${cid}" 5900/tcp | head -n1)

deadline=$((SECONDS + TIMEOUT))
# Quiet: a reset while websockify is still binding is expected noise.
until curl -fso /dev/null "http://${web}/vnc.html"; do
  running || fail "container exited before noVNC answered"
  ((SECONDS < deadline)) || fail "noVNC did not answer within ${TIMEOUT}s"
  sleep 2
done
echo "noVNC - ok" >&2

# The RFB handshake opens with the server's protocol version, e.g. "RFB 003.008".
exec 3<>"/dev/tcp/${vnc%:*}/${vnc##*:}"
read -r -n 12 -t 10 banner <&3 || true
exec 3>&-
[[ ${banner} == RFB* ]] || fail "VNC port did not answer with an RFB banner: '${banner}'"
echo "wayvnc - ok (${banner})" >&2

# docker top needs a pid column in the ps format it is handed.
until docker top "${cid}" -o pid,args | grep -qE '^ *[0-9]+ +/opt/Orca/orca-ide( |$)'; do
  running || fail "container exited before Orca started"
  ((SECONDS < deadline)) || fail "Orca process did not appear within ${TIMEOUT}s"
  sleep 2
done
echo "orca - started" >&2

# Quitting Orca ends cage and the container, so a crash shows up as an exit.
sleep "${SETTLE}"
running || fail "container exited within ${SETTLE}s of Orca starting"
echo "orca - still running after ${SETTLE}s" >&2

[[ $(docker exec "${cid}" git config --global user.email) == smoke@example.com ]] \
  || fail "GIT_USER_EMAIL did not reach the global git config"
echo "git identity - ok" >&2

versions() {
  docker run --rm --pull never "${image}" "$@" 2>&1 | head -n1
}

{
  echo "### ${TARGET}"
  echo
  echo "\`${image}\`"
  echo
  echo "| Component | Version |"
  echo "| --- | --- |"
  echo "| orca-ide | $(versions orca-ide --version) |"
  echo "| claude | $(versions claude --version) |"
  echo "| codex | $(versions codex --version) |"
  echo "| cage | $(versions cage -v) |"
  echo "| wayvnc | $(versions wayvnc --version) |"
  echo "| websockify | $(versions python3 -c 'import websockify; print(websockify.__version__)') |"
  echo "| stack | :white_check_mark: noVNC, RFB \`${banner}\`, Orca up after ${SETTLE}s |"
  echo
} >> "${SUMMARY}"
