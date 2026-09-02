# syntax=docker/dockerfile:1.27

FROM golang:1.27.1-alpine3.23@sha256:d9e2f2f07b10cc922da3e80e035c3058810b328d5aef82d2c63680967c5e2ec9 AS build

# The tag is human-readable provenance; the immutable commit is what is built.
# Renovate updates both from the same upstream tag.
# renovate: datasource=github-tags depName=acme-dns/acme-dns versioning=semver
ARG ACME_DNS_VERSION=v2.0.2
ARG ACME_DNS_COMMIT=4e5a69e5fb742dde4f755b7f56aee2aea76e19bf

# Upstream release dependency overrides for published security fixes.
# renovate: datasource=go depName=golang.org/x/crypto
ARG GO_X_CRYPTO_VERSION=v0.55.0
# renovate: datasource=go depName=golang.org/x/net
ARG GO_X_NET_VERSION=v0.58.0
# renovate: datasource=go depName=golang.org/x/text
ARG GO_X_TEXT_VERSION=v0.41.0

ENV GOTOOLCHAIN=local

ARG TARGETOS
ARG TARGETARCH
# hadolint ignore=DL3062
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    set -eu; \
    go mod download -json "github.com/joohoi/acme-dns@${ACME_DNS_COMMIT}" > /tmp/module.json; \
    module_dir="$(sed -n 's/^[[:space:]]*"Dir": "\(.*\)",$/\1/p' /tmp/module.json)"; \
    test -n "${module_dir}"; \
    mkdir -p /out/etc/acme-dns /out/var/lib/acme-dns /out/licenses/acme-dns; \
    cp -R "${module_dir}" /src; \
    chmod -R u+w /src; \
    go -C /src get \
      "golang.org/x/crypto@${GO_X_CRYPTO_VERSION}" \
      "golang.org/x/net@${GO_X_NET_VERSION}" \
      "golang.org/x/text@${GO_X_TEXT_VERSION}"; \
    go -C /src mod tidy; \
    CGO_ENABLED=0 GOOS="${TARGETOS}" GOARCH="${TARGETARCH}" \
      go -C /src build -trimpath -ldflags="-s -w -buildid=" -o /out/acme-dns .; \
    cp /src/LICENSE /out/licenses/acme-dns/LICENSE

FROM gcr.io/distroless/static-debian12:nonroot@sha256:afa5c872c891853ca7fcf1f12c3edb23f7eeef36189728842dd51042ff57f7ab

ARG ACME_DNS_VERSION

LABEL org.opencontainers.image.title="acme-dns" \
      org.opencontainers.image.description="Hardened container packaging for acme-dns" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/michidk/acme-dns-container" \
      org.opencontainers.image.vendor="michidk" \
      org.opencontainers.image.url="https://github.com/michidk/acme-dns-container" \
      org.opencontainers.image.version="${ACME_DNS_VERSION}"

COPY --from=build /out/acme-dns /usr/local/bin/acme-dns
COPY --from=build --chown=65532:65532 /out/etc/acme-dns /etc/acme-dns
COPY --from=build --chown=65532:65532 /out/var/lib/acme-dns /var/lib/acme-dns
COPY --from=build /out/licenses /licenses

USER 65532:65532
WORKDIR /var/lib/acme-dns
VOLUME ["/var/lib/acme-dns"]
EXPOSE 5353/tcp 5353/udp 8080/tcp
ENTRYPOINT ["/usr/local/bin/acme-dns"]
CMD ["-c", "/etc/acme-dns/config.cfg"]
