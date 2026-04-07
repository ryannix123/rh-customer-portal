# syntax=docker/dockerfile:1.7

# ---------- Builder ----------
FROM registry.access.redhat.com/ubi10/go-toolset:latest AS builder

ARG TARGETOS=linux
ARG TARGETARCH
ARG VERSION=dev

USER 0
WORKDIR /build

# Cache deps first
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Static-ish build, stripped, reproducible-ish
ENV CGO_ENABLED=0 \
    GOOS=${TARGETOS} \
    GOARCH=${TARGETARCH}

RUN go build \
      -trimpath \
      -ldflags "-s -w -X main.version=${VERSION}" \
      -o /out/agcm \
      ./cmd/agcm

# ---------- Runtime ----------
FROM registry.access.redhat.com/ubi10-minimal:latest

ARG VERSION=dev

LABEL org.opencontainers.image.title="agcm" \
      org.opencontainers.image.description="TUI for the Red Hat Customer Portal (containerized on UBI 10)" \
      org.opencontainers.image.source="https://github.com/atgreen/agcm" \
      org.opencontainers.image.licenses="GPL-3.0-or-later" \
      org.opencontainers.image.version="${VERSION}"

# ca-certificates for TLS to api.access.redhat.com; tzdata for sane timestamps
RUN microdnf install -y --nodocs ca-certificates tzdata \
 && microdnf clean all \
 && rm -rf /var/cache/yum

# Non-root user; OpenShift-friendly (arbitrary UID will still work because
# /home/agcm and /config are group-writable by root group)
RUN mkdir -p /home/agcm /config \
 && chgrp -R 0 /home/agcm /config \
 && chmod -R g=u /home/agcm /config

COPY --from=builder /out/agcm /usr/local/bin/agcm

ENV HOME=/home/agcm \
    XDG_CONFIG_HOME=/config \
    TERM=xterm-256color

USER 1001
WORKDIR /home/agcm
VOLUME ["/config"]

ENTRYPOINT ["/usr/local/bin/agcm"]