# Repository guide

This repository packages the upstream `acme-dns` server as a hardened,
multi-architecture container image and a reusable Helm chart. It does not fork
the upstream Go application.

## Layout

- `Dockerfile` builds the pinned upstream release.
- `examples/` contains a Docker Compose deployment and safe example config.
- `charts/acme-dns/` contains the Helm chart.
- `.github/workflows/` owns CI, releases, and version bumps.

## Verification

Run `just verify` before committing. It builds, smoke-tests, and vulnerability-
scans the image; checks the pinned upstream source; lints workflows, shell, and
the Dockerfile; and validates the chart in its supported modes. Docker is
required. Use `just verify-static` for checks that do not build the image.

## Release model

Repository releases and chart versions use semantic versions such as `v0.1.0`.
The chart's `appVersion` and the Dockerfile's `ACME_DNS_VERSION` identify the
packaged upstream release. A release publishes:

- `ghcr.io/michidk/acme-dns` for `linux/amd64` and `linux/arm64`;
- `oci://ghcr.io/michidk/charts/acme-dns`;
- a GitHub release with the packaged chart attached.

Keep the Dockerfile upstream version and `Chart.yaml` `appVersion` in sync.
Use Conventional Commits for commits and pull request titles.

## Boundaries

- Preserve upstream attribution and make the unofficial packaging relationship
  clear in public documentation and image metadata.
- Keep the image non-root and the chart's restrictive security context intact.
- Do not expose the registration/update API publicly by default.
- Never commit acme-dns account credentials, database contents, API TLS private
  keys, real domains, or public IP addresses.
- Do not edit generated chart archives or container build outputs into Git.
