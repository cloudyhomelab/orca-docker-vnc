variable "REGISTRY" { default = "docker.io" }
variable "NAMESPACE" { default = "binarycodes" }
variable "IMAGE" { default = "orca" }

# The repository the image is built from, for the OCI source label.
variable "SOURCE" { default = "https://github.com/cloudyhomelab/orca-docker" }

# The commit the image was built from, for the OCI revision label. HCL cannot
# read git, so the publish workflow passes the sha it checked out; a local build
# leaves it empty, which is the honest answer for a working tree.
variable "REVISION" { default = "" }

# The only place the Orca version changes; the Dockerfile declares the arg
# without a default. Orca ships amd64 and arm64 .debs under one release tag.
variable "ORCA_VERSION" { default = "1.4.209" }

# The agent CLIs installed beside Orca.
variable "CLAUDE_VERSION" { default = "2.1.280" }
variable "CODEX_VERSION" { default = "0.156.1" }

# GitHub CLI from its release .deb; Debian's package lags upstream by a year or more.
variable "GH_VERSION" { default = "2.101.0" }

variable "LOCAL" { default = true }

group "default" {
  targets = ["orca"]
}

target "orca" {
  context    = "."
  dockerfile = "Dockerfile"

  platforms = LOCAL ? [] : ["linux/amd64", "linux/arm64"]

  # The provenance attestation carries the source and revision too, but a label
  # is what `docker inspect` and Docker Hub read.
  labels = {
    "org.opencontainers.image.title"       = IMAGE
    "org.opencontainers.image.description" = "Orca IDE fullscreen in a headless Wayland kiosk, served over VNC and noVNC"
    "org.opencontainers.image.version"     = ORCA_VERSION
    "org.opencontainers.image.source"      = SOURCE
    "org.opencontainers.image.revision"    = REVISION
  }

  args = {
    ORCA_VERSION   = ORCA_VERSION
    CLAUDE_VERSION = CLAUDE_VERSION
    CODEX_VERSION  = CODEX_VERSION
    GH_VERSION     = GH_VERSION
  }

  tags = [
    "${REGISTRY}/${NAMESPACE}/${IMAGE}:latest",
    "${REGISTRY}/${NAMESPACE}/${IMAGE}:${ORCA_VERSION}",
  ]
}
