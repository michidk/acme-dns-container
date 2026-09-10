set dotenv-load := false

helm_image := "alpine/helm:4.3.0@sha256:a6cf54599ccb99d90cf0712b30f03fdb3cab062e6b94e0418cc4db7e8a1464b2"
kubeconform_image := "ghcr.io/yannh/kubeconform:v0.7.0-alpine@sha256:8f0eeaaa96ba27ba1500b0e4b1c215acc358d159c62a7ecae58d7a03403287b0"
actionlint_image := "rhysd/actionlint:1.7.12@sha256:b1934ee5f1c509618f2508e6eb47ee0d3520686341fec936f3b79331f9315667"
hadolint_image := "hadolint/hadolint:v2.14.0-alpine@sha256:7aba693c1442eb31c0b015c129697cb3b6cb7da589d85c7562f9deb435a6657c"
shellcheck_image := "koalaman/shellcheck:v0.11.0@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d"
trivy_image := "aquasec/trivy:0.74.0@sha256:62b1e65e8869bc4b4c6aa4fa2b21595256c7c2f6018a9d9ad61caf87187c1969"

default:
    @just --list

verify: verify-static verify-image

verify-static:
    @jq empty renovate.json charts/acme-dns/values.schema.json
    @./scripts/verify-upstream.sh
    @docker run --rm -i {{ hadolint_image }} < Dockerfile
    @docker run --rm -v "{{ justfile_directory() }}:/work" -w /work {{ shellcheck_image }} scripts/*.sh
    @docker run --rm -v "{{ justfile_directory() }}:/work" -w /work {{ actionlint_image }}
    @docker run --rm -v "{{ justfile_directory() }}:/work" -w /work {{ helm_image }} lint --strict charts/acme-dns
    @docker run --rm -v "{{ justfile_directory() }}:/work" -w /work {{ helm_image }} template acme-dns charts/acme-dns --namespace acme-dns | docker run --rm -i {{ kubeconform_image }} -strict -summary -ignore-missing-schemas
    @docker run --rm -v "{{ justfile_directory() }}:/work" -w /work {{ helm_image }} template acme-dns charts/acme-dns --namespace acme-dns --set config.existingConfigMap=acme-dns-config --set persistence.enabled=false >/dev/null
    @docker run --rm -v "{{ justfile_directory() }}:/work" -w /work {{ helm_image }} template acme-dns charts/acme-dns --namespace acme-dns --set config.existingSecret=acme-dns-config --set persistence.existingClaim=acme-dns-data >/dev/null
    @! docker run --rm -v "{{ justfile_directory() }}:/work" -w /work {{ helm_image }} template acme-dns charts/acme-dns --set config.existingConfigMap=a --set config.existingSecret=b >/dev/null 2>&1
    @! docker run --rm -v "{{ justfile_directory() }}:/work" -w /work {{ helm_image }} template acme-dns charts/acme-dns --set replicaCount=2 >/dev/null 2>&1

verify-image:
    docker build --tag acme-dns:verify .
    docker run --rm acme-dns:verify -h
    ./scripts/smoke-test.sh acme-dns:verify
    @mkdir -p .dist .cache/trivy
    docker save --output .dist/acme-dns-verify.tar acme-dns:verify
    docker run --rm -v "{{ justfile_directory() }}/.dist:/scan:ro" -v "{{ justfile_directory() }}/.cache/trivy:/root/.cache" {{ trivy_image }} image --input /scan/acme-dns-verify.tar --scanners vuln --ignore-unfixed --severity HIGH,CRITICAL --exit-code 1 --no-progress

package-chart:
    @mkdir -p .dist
    docker run --rm -v "{{ justfile_directory() }}:/work" -w /work {{ helm_image }} package charts/acme-dns --destination .dist
