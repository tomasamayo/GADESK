#!/usr/bin/env bash
set -euo pipefail
umask 077
gadesk_dir=/opt/gadesk/server
gadesk_web=/www/wwwroot/GA/DATAX/GADESK
gadesk_source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$EUID" -ne 0 ]]; then
  echo 'Run this deployment as root.' >&2
  exit 1
fi
command -v docker >/dev/null
docker compose version
install -d -m 700 "$gadesk_dir" "$gadesk_dir/data"
install -d -m 755 "$gadesk_web" "$gadesk_web/downloads"
if [[ -f "$gadesk_dir/compose.yml" ]]; then
  cp -p "$gadesk_dir/compose.yml" "$gadesk_dir/compose.yml.previous"
fi
install -m 600 "$gadesk_source_dir/compose.yml" "$gadesk_dir/compose.yml"
cd "$gadesk_dir"
docker compose config --quiet
docker compose pull
docker compose up -d hbbs
for gadesk_attempt in {1..60}; do
  [[ -s data/id_ed25519.pub ]] && break
  sleep 1
done
test -s data/id_ed25519.pub
chmod 600 data/id_ed25519
chmod 644 data/id_ed25519.pub
docker compose up -d hbbr
if command -v ufw >/dev/null && ufw status | grep -q 'Status: active'; then
  ufw allow 21115:21117/tcp comment 'GADESK signaling and relay'
  ufw allow 21116/udp comment 'GADESK NAT traversal'
fi
python3 - "$gadesk_dir/data/id_ed25519.pub" "$gadesk_web/client-config.json" <<'PY'
import base64
import json
import pathlib
import sys

key = pathlib.Path(sys.argv[1]).read_text().strip()
if len(base64.b64decode(key, validate=True)) != 32:
    raise SystemExit('Invalid GADESK public key')
config = {
    'app_name': 'GADESK',
    'id_server': 'gadesk.grupoamayo.com:21116',
    'relay_server': 'gadesk.grupoamayo.com:21117',
    'key': key,
    'version': '1.5.1',
}
path = pathlib.Path(sys.argv[2])
path.write_text(json.dumps(config, indent=2) + '\n')
path.chmod(0o644)
print(json.dumps(config))
PY
docker compose ps
