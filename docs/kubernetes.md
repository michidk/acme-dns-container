# Kubernetes deployment

## Prerequisites

- A Kubernetes cluster with a `LoadBalancer` implementation, or another way to
  expose both TCP and UDP port 53. The chart defaults to `ClusterIP`; choose
  the external exposure deliberately.
- A stable public IPv4 and/or IPv6 address for the authoritative DNS Service.
- A delegated DNS zone such as `auth.example.com`.
- A default StorageClass, unless an existing claim is supplied.

Do not place acme-dns behind a normal HTTP ingress for DNS traffic. DNS needs
both TCP and UDP port 53. The optional chart ingress is only for the HTTP API.

## Configuration ownership

By default the chart renders `config.cfg` from `values.yaml`. For advanced or
secret-bearing configuration, supply exactly one existing object:

```yaml
config:
  existingSecret: acme-dns-config
```

or:

```yaml
config:
  existingConfigMap: acme-dns-config
```

The object must contain a `config.cfg` key. A Secret is appropriate when a
PostgreSQL connection string contains credentials. The generated SQLite config
does not contain credentials.

When an existing object uses ports other than DNS `5353` and API `8080`, keep
the declared container ports aligned:

```yaml
containerPorts:
  dns: 1053
  api: 18080
```

## Persistence

The default SQLite database uses a 1 GiB `ReadWriteOnce` PersistentVolumeClaim.
Use an existing claim with:

```yaml
persistence:
  existingClaim: acme-dns-data
```

Disabling persistence uses `emptyDir` and loses every account and TXT record on
rescheduling. This is suitable only for disposable testing.

The default rollout strategy is `Recreate`, which prevents two Pods from using
the same SQLite database during an upgrade. Keep one replica with SQLite. An
external PostgreSQL deployment can use more replicas only after validating the
upstream behavior and DNS traffic topology for that design.

## API exposure

The API Service defaults to `ClusterIP`. This lets in-cluster clients such as
cert-manager reach it without publishing registration and update endpoints to
the internet.

If an external client needs the API, prefer a private load balancer, VPN, or
authenticated reverse proxy. The chart supports an API ingress, but enabling it
is an explicit security decision. TLS at the ingress does not authenticate the
registration endpoint. Set `config.api.disableRegistration: true` after all
required accounts have been created.

When acme-dns itself terminates API TLS, set both probe schemes to `HTTPS`:

```yaml
livenessProbe:
  scheme: HTTPS
readinessProbe:
  scheme: HTTPS
```

## cert-manager

cert-manager has a built-in `acmeDNS` DNS-01 solver. Store the JSON account map
from acme-dns registration in a Kubernetes Secret, then reference it from an
Issuer or ClusterIssuer:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    email: operator@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-account-key
    solvers:
      - dns01:
          acmeDNS:
            host: http://acme-dns-api.acme-dns.svc.cluster.local:8080
            accountSecretRef:
              name: acme-dns-accounts
              key: acmedns.json
        selector:
          dnsZones:
            - example.com
```

The account Secret belongs in the same namespace as the cert-manager controller
for a `ClusterIssuer`, according to cert-manager's secret resource namespace
configuration. Never put the returned account JSON into Helm values committed
to Git.

## Upgrades and backups

Back up the SQLite database before upgrades. A Kubernetes PVC is persistence,
not a backup. The image does not alter database contents during container
startup, but upstream releases can include schema or behavior changes; review
their release notes before updating `appVersion`.

Render and inspect changes before applying them:

```sh
helm template acme-dns oci://ghcr.io/michidk/charts/acme-dns \
  --version 0.1.0 \
  --namespace acme-dns \
  --values values.yaml
```
