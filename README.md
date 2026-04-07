# agcm on UBI 10

A platform-agnostic, multi-arch container image for [`agcm`](https://github.com/atgreen/agcm) — Anthony Green's terminal UI for the Red Hat Customer Portal API — built on Red Hat Universal Base Image 10.

[![Build and Push agcm Container](https://github.com/ryannix123/rh-customer-portal/actions/workflows/build.yml/badge.svg)](https://github.com/ryannix123/rh-customer-portal/actions/workflows/build.yml)

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

The simplest way to use this image is to run a long-lived container in the background and `podman exec` into it whenever you need agcm. This avoids any volumes or host config files — your auth token and presets live inside the container's writable layer for as long as the container exists.

### 1. Start the container (once per session)

```bash
podman run -dit --name agcm \
  --entrypoint sleep \
  quay.io/ryan_nix/agcm:latest infinity
```

This launches a detached container named `agcm` that just sleeps forever, ready to accept `exec` commands.

### 2. Authenticate (once per container)

Get an offline token from <https://access.redhat.com/management/api>, then:

```bash
podman exec -it agcm agcm auth login
```

### 3. Use agcm

```bash
podman exec -it agcm agcm                           # Launch TUI
podman exec -it agcm agcm list cases --status open  # CLI mode
podman exec -it agcm agcm export case 01234567      # Export a case to markdown
podman exec -it agcm agcm search "kernel panic"     # Search cases and KCS solutions
```

You can quit the TUI with `q` as many times as you like — the container keeps running, and your auth token persists between sessions.

### 4. Stop when done

```bash
podman rm -f agcm
```

This destroys the container and everything in it, including the offline token. Next session, repeat from step 1. If you'd rather your token survive container removal, use a named volume — see [Persistent variant](#persistent-variant) below.

## Recommended shell aliases

Drop these in your `~/.zshrc` or `~/.bashrc`:

```bash
alias agcm='podman exec -it agcm agcm'
alias agcm-start='podman run -dit --name agcm --entrypoint sleep quay.io/ryan_nix/agcm:latest infinity'
alias agcm-stop='podman rm -f agcm'
```

Daily flow becomes:

```bash
agcm-start                  # once per session
agcm auth login             # once per container
agcm                        # whenever you want it
agcm list cases --status open
agcm-stop                   # when you're done
```

See the [upstream agcm README](https://github.com/atgreen/agcm#readme) for the full command and keyboard reference.

## Persistent variant

If you'd rather not re-authenticate every session, use a named volume mounted at `/config` (which is where the container sets `XDG_CONFIG_HOME`):

```bash
podman volume create agcm-config

podman run -dit --name agcm \
  -v agcm-config:/config \
  --entrypoint sleep \
  quay.io/ryan_nix/agcm:latest infinity
```

The volume lives inside the Podman machine VM and survives `podman rm -f agcm`. Nuke it with `podman volume rm agcm-config` if you ever need to reset.

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