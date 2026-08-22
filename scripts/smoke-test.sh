#!/usr/bin/env bash

set -euo pipefail

image="${1:-acme-dns:verify}"
container_name="acme-dns-smoke-$$"

cleanup() {
  status=$?
  trap - EXIT
  if [[ $status -ne 0 ]]; then
    docker logs "$container_name" >&2 || true
  fi
  docker stop "$container_name" >/dev/null 2>&1 || true
  exit "$status"
}
trap cleanup EXIT

docker run --detach --rm \
  --name "$container_name" \
  --read-only \
  --tmpfs /var/lib/acme-dns:rw,noexec,nosuid,size=16m,uid=65532,gid=65532 \
  --volume "$PWD/examples/config.cfg:/etc/acme-dns/config.cfg:ro" \
  --publish 127.0.0.1::5353/tcp \
  --publish 127.0.0.1::5353/udp \
  --publish 127.0.0.1::8080/tcp \
  "$image" >/dev/null

api_address="$(docker port "$container_name" 8080/tcp)"
api_port="${api_address##*:}"

for _ in {1..30}; do
  if curl --fail --silent --show-error "http://127.0.0.1:${api_port}/health" >/dev/null; then
    break
  fi
  sleep 1
done
curl --fail --silent --show-error "http://127.0.0.1:${api_port}/health" >/dev/null

registration="$(curl --fail --silent --show-error --request POST "http://127.0.0.1:${api_port}/register")"
python3 -c '
import json
import sys

payload = json.loads(sys.argv[1])
required = {"username", "password", "fulldomain", "subdomain", "allowfrom"}
missing = required.difference(payload)
if missing:
    raise SystemExit(f"registration response is missing: {sorted(missing)}")
' "$registration"

dns_udp_address="$(docker port "$container_name" 5353/udp)"
dns_tcp_address="$(docker port "$container_name" 5353/tcp)"
dns_udp_port="${dns_udp_address##*:}"
dns_tcp_port="${dns_tcp_address##*:}"

python3 - "$dns_udp_port" "$dns_tcp_port" <<'PY'
import socket
import struct
import sys

query_id = 0xAC1E
name = b"".join(bytes([len(label)]) + label for label in b"auth.example.com".split(b".")) + b"\x00"
packet = struct.pack("!HHHHHH", query_id, 0x0100, 1, 0, 0, 0) + name + struct.pack("!HH", 1, 1)


def validate(response: bytes, protocol: str) -> None:
    if len(response) < 12:
        raise SystemExit(f"short {protocol} DNS response")
    response_id, flags, _, answers, _, _ = struct.unpack("!HHHHHH", response[:12])
    if response_id != query_id or not flags & 0x8000 or flags & 0x000F or answers < 1:
        raise SystemExit(f"invalid {protocol} DNS response header")


udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
udp.settimeout(5)
udp.sendto(packet, ("127.0.0.1", int(sys.argv[1])))
validate(udp.recvfrom(4096)[0], "UDP")

tcp = socket.create_connection(("127.0.0.1", int(sys.argv[2])), timeout=5)
tcp.sendall(struct.pack("!H", len(packet)) + packet)
size = struct.unpack("!H", tcp.recv(2))[0]
response = b""
while len(response) < size:
    chunk = tcp.recv(size - len(response))
    if not chunk:
        raise SystemExit("short TCP DNS response body")
    response += chunk
validate(response, "TCP")
PY
