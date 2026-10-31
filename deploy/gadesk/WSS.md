# GADESK over HTTPS

This alternative uses only BetterDesk's Go backend, pinned to
`eb84feff61c25595e326294fccd13e27ccd14a29` (3.5.200). It builds
`Dockerfile.server`; it does not install the BetterDesk web console. The public
entry points are the existing HTTPS virtual host's `/ws/id` and `/ws/relay`.
The API and native TCP/UDP listeners remain inside the container network.

Copy `compose.wss.yml`, `deploy-wss.sh` and `nginx-wss.conf` into one private
directory on the server and run `bash deploy-wss.sh` as root. Docker Compose,
Git, Python 3 and the existing aaPanel Nginx installation are required. The
initial Go image build requires Internet access and available disk space.

The script uses `/opt/gadesk/wss`, creates the external Docker bridge
`gadesk-wss`, and records its gateway in the private `.env` as
`GADESK_TRUSTED_PROXIES`. It copies the official server's existing Ed25519 keys
from `/opt/gadesk/server/data` and refuses a different public identity. Its
database is a separate `data/gadesk.sqlite3`. Do not point it at the official
server's SQLite database.

Nginx's extension is installed at
`/www/server/panel/vhost/nginx/extension/gadesk.grupoamayo.com/gadesk-wss.conf`.
An existing extension is backed up privately under `/opt/gadesk/wss` before
replacement. Failed Nginx validation/reload restores that file. The script
checks local and HTTPS WebSocket upgrades before updating the public
`client-config.json`. An upgrade test verifies routing and TLS, not successful
remote control.

GADESK clients need the same host and public key, `allow-websocket=Y`, and
`api-server=https://gadesk.grupoamayo.com`. This API URL selects WSS; the public
Nginx configuration does not expose the backend's management API. No new shared
secret is required in the clients. Open enrollment and compatibility policies
allow stock client initiation, including multiple devices behind one NAT;
the remote device's normal password/approval remains required. All sessions
use relay, so server bandwidth carries their traffic. Peer encryption remains
inside the WSS transport.

Before publishing clients, verify native registration persists, a controlled
device receives a connection, and a two-client encrypted remote session works.
Include same-NAT clients, idle/reconnect behavior, Android screen permissions,
and macOS accessibility/screen-recording permissions in live validation. The
effective client IP in backend logs should match the Nginx client address;
adjust the trusted proxy CIDR if Docker presents a different source address.

The deployment script leaves the official containers and firewall untouched.
After public WSS validation, the current deployment stopped the owned
`gadesk-hbbs`/`gadesk-hbbr` containers and removed its raw-port UFW rules;
their private keys and database remain available. To roll back, stop the WSS Compose project,
restore the previous Nginx extension (or remove it if none existed), run
Nginx's configuration test, and reload Nginx. Retain its private keys/database
until the rollback has been verified. Restore the public configuration to the
transport actually in use. Restart the official services and restore their
specific firewall rules only if that transport becomes publicly reachable.

The relay currently counts the shared Docker proxy IP, so its per-IP limit is
explicitly 256 connections (up to 128 paired sessions across the deployment).
Additional file-transfer or other sessions also consume slots. This is a finite
global ceiling behind the proxy; review capacity before increasing it.
