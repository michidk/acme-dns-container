# acme-dns container and Helm chart

Production-oriented container packaging and a Kubernetes Helm chart for
[acme-dns](https://github.com/acme-dns/acme-dns), the narrowly scoped DNS server
for ACME DNS-01 challenges.

This is an unofficial packaging project. The application itself is developed
upstream; this repository owns the non-root multi-architecture image, Helm
deployment, CI, and release automation.

## What you get

- `linux/amd64` and `linux/arm64` images at `ghcr.io/michidk/acme-dns`
- A distroless, non-root runtime with no Linux capabilities required
- An immutable upstream source commit verified through Go's checksum database
- Renovate-managed downstream dependency overrides for published security fixes
- A persistent SQLite deployment by default
- Separate DNS and API Kubernetes Services, so the update API stays private
- An OCI Helm chart at `oci://ghcr.io/michidk/charts/acme-dns`
- Renovate-managed upstream, base image, action, and chart dependencies
- Signed images with build provenance and an SBOM on tagged releases

## Docker Compose

Copy [`examples/compose.yaml`](examples/compose.yaml) and
[`examples/config.cfg`](examples/config.cfg), then replace every example domain
and address. Start the service with:

```sh
docker compose up -d
```

DNS is published on TCP and UDP port 53. The API is deliberately bound only to
`127.0.0.1:8080`; put it behind an authenticated private network or explicitly
change the binding if a remote ACME client needs it.

The container runs as UID/GID `65532`. Named volumes work without extra setup.
If you use a bind mount for `/var/lib/acme-dns`, make it writable by that UID.

## Helm

Create a values file for the delegated zone:

```yaml
config:
  general:
    domain: auth.example.com
    nsname: auth.example.com
    nsadmin: admin.example.com
    records:
      - auth.example.com. A 192.0.2.10
      - auth.example.com. NS auth.example.com.

service:
  dns:
    type: LoadBalancer
    loadBalancerIP: 192.0.2.10
```

Install the OCI chart:

```sh
helm install acme-dns oci://ghcr.io/michidk/charts/acme-dns \
  --version 0.1.0 \
  --namespace acme-dns \
  --create-namespace \
  --values values.yaml
```

The DNS Service publishes TCP and UDP port 53. The API Service remains
`ClusterIP` by default. See [Kubernetes deployment](docs/kubernetes.md) for DNS
delegation, existing configuration objects, persistence, ingress, cert-manager,
and upgrade guidance.

## DNS setup

At your normal DNS provider, delegate a dedicated zone to acme-dns:

```dns
auth.example.com.  A   192.0.2.10
auth.example.com.  NS  auth.example.com.
```

Then register an account through the private API and point each certificate
name at its assigned acme-dns name:

```dns
_acme-challenge.example.com. CNAME <account-id>.auth.example.com.
```

The registration response contains credentials. Store them in a secret manager;
they grant TXT updates for the assigned record and must never be committed.
The full upstream protocol and client examples are documented in the
[acme-dns README](https://github.com/acme-dns/acme-dns#usage).

## Image verification

Tagged images are signed keylessly by GitHub Actions. Verify one with Cosign:

```sh
cosign verify ghcr.io/michidk/acme-dns:0.1.0 \
  --certificate-identity-regexp='^https://github\.com/michidk/acme-dns(-container)?/\.github/workflows/release\.yml@refs/tags/v0\.1\.0$' \
  --certificate-oidc-issuer='https://token.actions.githubusercontent.com'
```

## Development

Docker, Git, `curl`, Python 3, `jq`, and [`just`](https://just.systems/) are
required:

```sh
just verify
```

That command builds and vulnerability-scans the image; exercises its DNS, API,
and SQLite paths; checks the workflows and Dockerfile; and lints the chart in its
generated, existing-ConfigMap, and existing-Secret deployment modes.

Releases follow Semantic Versioning for the packaging project. The packaged
upstream version is recorded separately in the Dockerfile and chart
`appVersion`; see [Releasing](docs/releasing.md).

## License and attribution

The packaging in this repository is MIT licensed. The container builds and
redistributes [acme-dns](https://github.com/acme-dns/acme-dns), also under the
MIT License; its license is included at `/licenses/acme-dns/LICENSE` in the
image.
