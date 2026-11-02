#!/usr/bin/env bash
set -euo pipefail
umask 077

gadesk_dir=/opt/gadesk/wss
gadesk_official_data=/opt/gadesk/server/data
gadesk_web=/www/wwwroot/GA/DATAX/GADESK
gadesk_extension=/www/server/panel/vhost/nginx/extension/gadesk.grupoamayo.com
gadesk_commit=eb84feff61c25595e326294fccd13e27ccd14a29
gadesk_source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gadesk_patch_file="$gadesk_source_dir/patches/betterdesk-google.patch"
gadesk_patch_sha="$(python3 - "$gadesk_patch_file" <<'PY'
import hashlib
import pathlib
import sys
print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"
if [[ "$EUID" -ne 0 ]]; then
  echo 'Run this deployment as root.' >&2
  exit 1
fi
for gadesk_command in docker git python3; do
  command -v "$gadesk_command" >/dev/null
done
if [[ -x /www/server/nginx/sbin/nginx ]]; then
  gadesk_nginx=/www/server/nginx/sbin/nginx
else
  gadesk_nginx="$(command -v nginx)"
fi
docker compose version
install -d -m 700 "$gadesk_dir" "$gadesk_dir/data"

python3 - "$gadesk_official_data" "$gadesk_dir/data" <<'PY'
import base64
import os
import pathlib
import sys

source, target = map(pathlib.Path, sys.argv[1:])
public = (source / 'id_ed25519.pub').read_text().strip()
expected = '8wk8CXUVJg69QnzZH2of2LjRk7VsY+OP+Tub87xv+XM='
private = base64.b64decode((source / 'id_ed25519').read_text().strip(), validate=True)
if public != expected or len(private) != 64 or private[32:] != base64.b64decode(public, validate=True):
    raise SystemExit('Official GADESK keys do not match the pinned public identity')
for name, value, mode in [('id_ed25519', base64.b64encode(private), 0o600), ('id_ed25519.pub', public.encode(), 0o644)]:
    path = target / name
    if path.is_symlink():
        raise SystemExit('Refusing a symlink in the WSS key directory')
    if path.exists():
        if path.read_bytes().strip() != value:
            raise SystemExit('Existing WSS key differs; refusing to replace its identity')
    else:
        with path.open('xb') as stream:
            stream.write(value)
        os.chmod(path, mode)
PY

if ! docker network inspect gadesk-wss >/dev/null 2>&1; then
  docker network create --driver bridge gadesk-wss >/dev/null
fi
[[ "$(docker network inspect -f '{{.Driver}}' gadesk-wss)" == bridge ]]
gadesk_gateway="$(docker network inspect -f '{{(index .IPAM.Config 0).Gateway}}' gadesk-wss)"
gadesk_proxy_cidr="$(python3 - "$gadesk_gateway" <<'PY'
import ipaddress
import sys
address = ipaddress.ip_address(sys.argv[1])
print(f'{address}/{address.max_prefixlen}')
PY
)"
case "$(docker info --format '{{.Architecture}}')" in
  x86_64|amd64) gadesk_arch=amd64 ;;
  aarch64|arm64) gadesk_arch=arm64 ;;
  *) echo 'Unsupported Docker server architecture.' >&2; exit 1 ;;
esac
printf 'GADESK_TRUSTED_PROXIES=%s\nGADESK_TARGETARCH=%s\nGADESK_BACKEND_PATCH_SHA=%s\n' "$gadesk_proxy_cidr" "$gadesk_arch" "$gadesk_patch_sha" > "$gadesk_dir/.env"
install -m 600 "$gadesk_source_dir/compose.wss.yml" "$gadesk_dir/compose.yml"

if [[ ! -d "$gadesk_dir/source/.git" ]]; then
  git init -q "$gadesk_dir/source"
fi
git -C "$gadesk_dir/source" fetch --quiet --depth 1 https://github.com/UNITRONIX/BetterDesk.git "$gadesk_commit"
if git -C "$gadesk_dir/source" apply --reverse --check "$gadesk_patch_file" 2>/dev/null; then
  git -C "$gadesk_dir/source" apply --reverse "$gadesk_patch_file"
fi
git -C "$gadesk_dir/source" diff --quiet
git -C "$gadesk_dir/source" diff --cached --quiet
git -C "$gadesk_dir/source" -c advice.detachedHead=false checkout --quiet --detach "$gadesk_commit"
[[ "$(git -C "$gadesk_dir/source" rev-parse HEAD)" == "$gadesk_commit" ]]
git -C "$gadesk_dir/source" apply --check "$gadesk_patch_file"
git -C "$gadesk_dir/source" apply "$gadesk_patch_file"
cd "$gadesk_dir"
docker compose config --quiet
docker compose build backend
docker compose up -d backend
for gadesk_attempt in {1..60}; do
  gadesk_health="$(docker inspect -f '{{.State.Health.Status}}' gadesk-wss-backend)"
  [[ "$gadesk_health" == healthy ]] && break
  if [[ "$gadesk_health" == unhealthy ]]; then
    echo 'WSS backend health check failed; proxy configuration was not changed.' >&2
    exit 1
  fi
  sleep 2
done
[[ "$gadesk_health" == healthy ]]

install -d -m 755 "$gadesk_extension"
gadesk_proxy_path="$gadesk_extension/gadesk-wss.conf"
gadesk_account_inc="$gadesk_extension/gadesk-account-proxy.inc"
gadesk_account_rates=/www/server/panel/vhost/nginx/00-gadesk-account-rates.conf
gadesk_account_backup="$(mktemp -d "$gadesk_dir/nginx-accounts.previous.XXXXXX")"
for gadesk_config_file in "$gadesk_account_inc" "$gadesk_account_rates"; do
  gadesk_config_name="$(basename "$gadesk_config_file")"
  if [[ -e "$gadesk_config_file" ]]; then
    cp -p "$gadesk_config_file" "$gadesk_account_backup/$gadesk_config_name"
  else
    touch "$gadesk_account_backup/$gadesk_config_name.absent"
  fi
done
gadesk_backup=
if [[ -e "$gadesk_proxy_path" ]]; then
  gadesk_backup="$(mktemp "$gadesk_dir/nginx-wss.previous.XXXXXX")"
  cp -p "$gadesk_proxy_path" "$gadesk_backup"
fi
restore_proxy_config() {
  if [[ -n "$gadesk_backup" ]]; then
    cp -p "$gadesk_backup" "$gadesk_proxy_path"
  else
    rm -f "$gadesk_proxy_path"
  fi
  for gadesk_config_file in "$gadesk_account_inc" "$gadesk_account_rates"; do
    gadesk_config_name="$(basename "$gadesk_config_file")"
    if [[ -e "$gadesk_account_backup/$gadesk_config_name.absent" ]]; then
      rm -f "$gadesk_config_file"
    else
      cp -p "$gadesk_account_backup/$gadesk_config_name" "$gadesk_config_file"
    fi
  done
}
install -m 644 "$gadesk_source_dir/nginx-account-proxy.inc" "$gadesk_account_inc"
install -m 644 "$gadesk_source_dir/nginx-account-rates.conf" "$gadesk_account_rates"
install -m 644 "$gadesk_source_dir/nginx-wss.conf" "$gadesk_proxy_path"
if ! "$gadesk_nginx" -t; then
  restore_proxy_config
  echo 'Nginx validation failed; previous extension configuration restored.' >&2
  exit 1
fi
if ! "$gadesk_nginx" -s reload; then
  restore_proxy_config
  echo 'Nginx reload failed; previous extension configuration restored.' >&2
  exit 1
fi

python3 - "$gadesk_web/client-config.json" <<'PY'
import base64
import hashlib
import http.client
import json
import os
import pathlib
import sys

for host, port, path, tls in [
    ('127.0.0.1', 21118, '/ws/id', False),
    ('127.0.0.1', 21119, '/ws/relay', False),
    ('gadesk.grupoamayo.com', 443, '/ws/id', True),
    ('gadesk.grupoamayo.com', 443, '/ws/relay', True),
]:
    connection = (http.client.HTTPSConnection if tls else http.client.HTTPConnection)(host, port, timeout=15)
    nonce = base64.b64encode(os.urandom(16)).decode()
    try:
        connection.request('GET', path, headers={
            'Connection': 'Upgrade', 'Upgrade': 'websocket',
            'Sec-WebSocket-Version': '13', 'Sec-WebSocket-Key': nonce,
        })
        response = connection.getresponse()
        expected = base64.b64encode(hashlib.sha1((nonce + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()).decode()
        if response.status != 101 or response.getheader('Sec-WebSocket-Accept') != expected:
            raise SystemExit(f'WebSocket upgrade failed: {host}:{port}{path} HTTP {response.status}')
    finally:
        connection.close()
    print(f'WebSocket upgrade verified: {host}:{port}{path}')

path = pathlib.Path(sys.argv[1])
config = json.loads(path.read_text()) if path.exists() else {}
key = '8wk8CXUVJg69QnzZH2of2LjRk7VsY+OP+Tub87xv+XM='
if config.get('key', key) != key:
    raise SystemExit('Public client configuration has a different server key')
config.update({
    'app_name': 'GADESK', 'version': '1.5.1',
    'id_server': 'gadesk.grupoamayo.com:21116',
    'relay_server': 'gadesk.grupoamayo.com:21117', 'key': key,
    'allow_websocket': True, 'api_server': 'https://gadesk.grupoamayo.com',
    'transport': 'wss',
})
temporary = path.with_suffix('.json.tmp')
temporary.write_text(json.dumps(config, indent=2) + '\n')
temporary.chmod(0o644)
temporary.replace(path)
PY
docker compose ps
echo 'WSS proxy upgrades verified. Native registration and a two-client session still require validation.'
