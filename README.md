# agcm on UBI 10

A platform-agnostic, multi-arch container image for [`agcm`](https://github.com/atgreen/agcm) — Anthony Green's terminal UI for the Red Hat Customer Portal API — built on Red Hat Universal Base Image 10.

[![Build and Push](https://github.com/ryannix123/agcm-on-ubi/actions/workflows/build.yml/badge.svg)](https://github.com/ryannix123/agcm-on-ubi/actions/workflows/build.yml)
[![Container Repository on Quay](https://quay.io/repository/ryan_nix/agcm/status "Container Repository on Quay")](https://quay.io/repository/ryan_nix/agcm)
[![License: GPL v3+](https://img.shields.io/badge/License-GPLv3+-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

> **Disclaimer:** This is a personal project and is **not** an official Red Hat product. It is not supported by Red Hat. The upstream `agcm` project is independently maintained by Anthony Green.

## What is this?

[`agcm`](https://github.com/atgreen/agcm) is an excellent keyboard-driven TUI for browsing, filtering, and exporting Red Hat support cases without leaving your terminal. This repository packages it as an OCI container so you can:

- Run it on any host with `podman` or `docker` — no Go toolchain, no `make`, no per-host installation.
- Get a consistent version across your laptop, your jump hosts, and your home lab.
- Pin to a specific release for reproducibility, or track `:latest` for daily UBI base updates.
- Run on both **`linux/amd64`** and **`linux/arm64`** (Apple Silicon, Ampere, Raspberry Pi 5, etc.).

## Image

```
quay.io/ryan_nix/agcm:latest
quay.io/ryan_nix/agcm:0.1.10
```

Built nightly from [`registry.access.redhat.com/ubi10-minimal`](https://catalog.redhat.com/software/containers/ubi10-minimal/) so CVE fixes in the base layer flow through automatically.

## Quick start

```bash
# One-time: authenticate with your Red Hat offline token
# Get one at https://access.redhat.com/management/api
podman run -it --rm \
  -v "$HOME/.config/agcm:/config/agcm:Z" \
  quay.io/ryan_nix/agcm:latest auth login

# Launch the TUI
podman run -it --rm \
  -v "$HOME/.config/agcm:/config/agcm:Z" \
  -e TERM \
  quay.io/ryan_nix/agcm:latest
```

### Recommended shell alias

Drop this in your `~/.zshrc` or `~/.bashrc` so `agcm` feels like a native binary:

```bash
alias agcm='podman run -it --rm \
  -v "$HOME/.config/agcm:/config/agcm:Z" \
  -e TERM \
  quay.io/ryan_nix/agcm:latest'
```

Then:

```bash
agcm                              # Launch TUI
agcm list cases --status open     # CLI mode
agcm export case 01234567         # Export a case to markdown
agcm search "kernel panic"        # Search cases and KCS solutions
```

See the [upstream agcm README](https://github.com/atgreen/agcm#readme) for the full command and keyboard reference.

## Configuration & token storage

Inside the container there is no D-Bus / Secret Service / macOS Keychain, so `agcm` automatically falls back to file-based token storage. The `-v "$HOME/.config/agcm:/config/agcm:Z"` bind mount persists three things across runs:

- The encrypted offline token
- Your `config.yaml` (API URL, default account/group, filter presets 1–9, 0)
- Any cached state

The container sets `XDG_CONFIG_HOME=/config`, so `agcm` writes everything under `/config/agcm` inside the container, which maps cleanly to `~/.config/agcm` on the host — the same path you'd get from a native install.

### `:Z` vs `:z` on SELinux hosts

The examples use `:Z` (private label) since you're the only user of the volume. If you're sharing the config dir between containers, use `:z` (shared label) instead. On non-SELinux hosts (macOS, most Ubuntu), the suffix is a harmless no-op.

## Image design

| Layer | Image | Purpose |
|---|---|---|
| Builder | `registry.access.redhat.com/ubi10/go-toolset` | Compiles `agcm` with `CGO_ENABLED=0` for a static binary |
| Runtime | `registry.access.redhat.com/ubi10-minimal` | Final image — `ca-certificates`, `tzdata`, and the binary |

- **Final image size:** ~95 MB across both architectures
- **User:** non-root UID 1001, GID 0 (OpenShift restricted-SCC compatible)
- **Cross-compiled, not emulated:** the Go build runs natively in the builder and uses `GOARCH=${TARGETARCH}` for arm64, so multi-arch builds finish in ~4 minutes instead of the ~hour you'd spend under QEMU

## Building locally

```bash
git clone https://github.com/ryannix123/agcm-on-ubi.git
cd agcm-on-ubi

# Single-arch (your host's native arch)
podman build -t agcm:dev --build-arg VERSION=dev .

# Multi-arch
podman build \
  --platform linux/amd64,linux/arm64 \
  --manifest agcm:dev \
  --build-arg VERSION=dev .
```

## CI/CD

This repo's [GitHub Actions workflow](.github/workflows/build.yml):

1. Polls the [upstream `atgreen/agcm` releases API](https://github.com/atgreen/agcm/releases) daily at 06:17 UTC.
2. Skips the build if the latest upstream tag is already in Quay (so daily runs are free when nothing's changed).
3. On a new release, checks out the upstream source at that exact tag, overlays this repo's `Containerfile`, and builds for `linux/amd64` and `linux/arm64`.
4. Pushes both `:VERSION` and `:latest` tags to `quay.io/ryan_nix/agcm`.

A manual `workflow_dispatch` with the `force` toggle rebuilds against the latest UBI base even when upstream hasn't moved — useful for picking up CVE fixes in `ubi10-minimal`.

## Related projects

- **[atgreen/agcm](https://github.com/atgreen/agcm)** — The upstream TUI this image packages. All credit for the actual application goes to [Anthony Green](https://github.com/atgreen).
- **[ryannix123/rh-customer-portal](https://github.com/ryannix123/rh-customer-portal)** — A companion project from my colleague exploring the Red Hat Customer Portal API.
- **[Red Hat Customer Portal API documentation](https://access.redhat.com/management/api)** — Official API reference and offline token management.
- **[Red Hat Universal Base Images](https://catalog.redhat.com/software/base-images)** — UBI 10 base image catalog.

## Other containerized OpenShift workloads

If you found this useful, you might also like my other personal "deploy open-source apps to OpenShift the right way" projects:

- [openemr-on-openshift](https://github.com/ryannix123/openemr-on-openshift) — OpenEMR EHR on OpenShift
- [nextcloud-on-openshift](https://github.com/ryannix123/nextcloud-on-openshift) — Nextcloud with Collabora and Talk HPB
- [openldap-on-openshift](https://github.com/ryannix123/openldap-on-openshift) — OpenLDAP as an LDAPS auth service
- [single-node-openshift](https://github.com/ryannix123/single-node-openshift) — SNO home lab automation

## License

The `agcm` source code is licensed under [GPL-3.0-or-later](https://github.com/atgreen/agcm/blob/master/LICENSE), copyright Anthony Green. The packaging files in this repository (Containerfile, GitHub Actions workflow, README) are released under the same license to keep things simple.

## Author

Ryan Nix — Senior Solutions Architect, Red Hat
[YouTube](https://www.youtube.com/@ryannix) · [GitHub](https://github.com/ryannix123)