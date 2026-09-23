# Orca in a container, fullscreen in the browser

[Orca](https://www.onorca.dev) runs fullscreen inside `cage` (a single-app Wayland kiosk compositor) on a headless wlroots backend. `wayvnc` exposes it over VNC, and `websockify` + noVNC serve it over HTTP.

    docker compose up

pulls `binarycodes/orca:latest` from Docker Hub. To build locally instead:

    docker buildx bake
    docker compose up

Then open `http://<docker-host>:6080/` in a browser. The page connects automatically and resizes Orca to the browser window.

Native VNC clients can use `localhost:5901` on the Docker host (loopback only). Remote: `ssh -L 5901:localhost:5901 user@host`; on macOS use `vnc://127.0.0.1:5901` (IPv4 literal, the forward is IPv4 only).

No authentication is configured on either port. Port 6080 is published on all interfaces, so restrict it with a firewall or put a TLS reverse proxy with auth in front of it.

Resolution: `ORCA_RESOLUTION` in `compose.yaml` (default 1920x1080) sets the initial size; noVNC then follows the browser window.

Orca version: `ORCA_VERSION` in `docker-bake.hcl`; the `.deb` for the target architecture (amd64 or arm64) is downloaded from the GitHub release.

## Publishing

`.github/workflows/pr.yml` lints, builds each platform natively and smoke tests the result. `.github/workflows/publish.yml` publishes `latest` and the Orca version tag to Docker Hub on every merged pull request that touches a build input, on dispatch, and weekly for Debian updates; images carry provenance and SBOM attestations and are signed with cosign. Secrets: `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` (Actions and Dependabot).

Git identity: `GIT_USER_NAME` and `GIT_USER_EMAIL`, read by compose from `.env` or the shell and written to the container's global git config at start:

    GIT_USER_NAME=Jane Doe
    GIT_USER_EMAIL=jane@example.com

Orca state lives in the `orca-home` volume. The image ships `git` but none of the agent CLIs Orca drives (Claude Code, Codex, ...); install them into the volume or bake them into the image.

Quitting Orca ends `cage`, and the container exits; `docker compose up` starts it again.
