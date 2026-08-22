# Releasing

The packaging project and upstream application have separate versions:

- `charts/acme-dns/Chart.yaml` `version` is this repository's release version.
- `Chart.yaml` `appVersion` and Dockerfile `ACME_DNS_VERSION` are the packaged
  upstream acme-dns version.

Renovate proposes upstream updates. Keep both upstream version fields in sync,
review upstream release notes, and run `just verify` before merging.

The Dockerfile also carries explicit `golang.org/x/*` overrides when upstream's
release module graph lags published security fixes. Renovate maintains those
versions, and CI blocks high or critical vulnerabilities with available fixes.

To publish, run the **Bump Version** workflow with `patch`, `minor`, or `major`.
It updates the chart version, commits to `main`, creates a `vX.Y.Z` tag, and
calls the release workflow. A manually pushed semantic-version tag runs the same
release path.

The release workflow:

1. verifies the tag matches the chart version;
2. builds and pushes a multi-architecture image with SBOM and provenance;
3. signs the image digest through GitHub's OIDC identity;
4. packages and pushes the OCI chart;
5. creates a GitHub release and attaches the chart archive.

The workflow uses the repository `GITHUB_TOKEN`; no long-lived registry or
signing key is needed. Branch rules must allow GitHub Actions to push the
version commit for the bump workflow to succeed.
