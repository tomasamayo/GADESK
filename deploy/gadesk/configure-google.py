#!/usr/bin/env python3
"""Configure Google after stopping the owned backend; never echo credentials."""
import json
import os
from pathlib import Path
import re
import sqlite3
import stat
import subprocess
import sys
import tempfile


SETTINGS = {
    'enabled': True,
    'prefer_sso': False,
    'display_name': 'Google',
    'issuer_url': 'https://accounts.google.com',
    'redirect_url': 'https://gadesk.grupoamayo.com/api/oidc/callback',
    'scopes': 'openid profile email',
    'use_pkce': True,
    'auto_discovery': True,
    'claim_username': 'sub',
    'claim_email': 'email',
    'claim_name': 'name',
    'claim_groups': 'groups',
    'default_role': 'pro',
    'allow_signup': True,
    'group_role_map': '',
    'authorization_url': '',
    'token_url': '',
    'userinfo_url': '',
    'allowed_private_cidrs': '',
    'panel_url': '',
}


def configure_google(config_path: Path, database_path: Path) -> Path:
    for path in (config_path, database_path):
        if path.is_symlink() or not path.is_file():
            raise ValueError('Expected existing regular configuration and database files')
    if stat.S_IMODE(config_path.stat().st_mode) & 0o077:
        raise ValueError('OAuth configuration must be private (mode 0600)')
    supplied = json.loads(config_path.read_text())
    if not isinstance(supplied, dict):
        raise ValueError('Invalid OAuth configuration')
    for key, value in supplied.items():
        if key in ('client_id', 'client_secret'):
            continue
        if key not in SETTINGS or type(value) is not type(SETTINGS[key]) or value != SETTINGS[key]:
            raise ValueError('OAuth configuration differs from the approved Google flow')
    client_id = supplied.get('client_id', '')
    secret = supplied.get('client_secret', '')
    if not isinstance(client_id, str) or not re.fullmatch(r'[A-Za-z0-9_-]+\.apps\.googleusercontent\.com', client_id):
        raise ValueError('Expected a Google web OAuth client ID')
    if not isinstance(secret, str) or len(secret) < 8 or any(c.isspace() for c in secret):
        raise ValueError('Expected a nonempty Google client secret')
    values = dict(SETTINGS, client_id=client_id, client_secret=secret)
    serialized = [(f'oidc.{key}', str(value).lower() if isinstance(value, bool) else value)
                  for key, value in values.items()]
    with sqlite3.connect(f'{database_path.resolve().as_uri()}?mode=rw', uri=True) as database:
        database.execute('SELECT key, value FROM server_config LIMIT 1')
        descriptor, backup_name = tempfile.mkstemp(prefix=database_path.name + '.backup-',
                                                  dir=database_path.parent)
        os.close(descriptor)
        backup_path = Path(backup_name)
        with sqlite3.connect(backup_path) as backup:
            database.backup(backup)
        database.execute('BEGIN IMMEDIATE')
        database.executemany('INSERT INTO server_config (key, value) VALUES (?, ?) '
                             'ON CONFLICT(key) DO UPDATE SET value=excluded.value', serialized)
    return backup_path


def main() -> int:
    if len(sys.argv) != 3:
        print('Usage: configure-google.py PRIVATE_CONFIG_JSON PRIVATE_SQLITE_DB', file=sys.stderr)
        return 2
    try:
        status = subprocess.run(['docker', 'inspect', '-f', '{{.State.Running}}',
                                 'gadesk-wss-backend'], capture_output=True, text=True,
                                check=True, timeout=15)
        if status.stdout.strip() != 'false':
            raise ValueError('Stop gadesk-wss-backend before configuring Google')
        backup = configure_google(Path(sys.argv[1]), Path(sys.argv[2]))
    except (ValueError, OSError, sqlite3.Error, subprocess.SubprocessError):
        print('Configuration not applied. Check private files, approved values, database '
              'and stopped backend. Credentials are not displayed.', file=sys.stderr)
        return 1
    print(f'Google configured. Private backup: {backup}')
    print('Start the backend and verify the Google login before announcing availability.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
