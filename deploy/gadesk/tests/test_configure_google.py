import importlib.util
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'configure-google.py'


class GoogleConfigurationTest(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('configure_google', SCRIPT)
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.database = self.root / 'gadesk.sqlite3'
        with sqlite3.connect(self.database) as db:
            db.execute('CREATE TABLE server_config (key TEXT PRIMARY KEY, value TEXT)')
            db.execute("INSERT INTO server_config VALUES ('existing', 'preserved')")
        self.config = self.root / 'google.json'

    def write_config(self, **extra):
        values = {'client_id': '123-test.apps.googleusercontent.com',
                  'client_secret': 'fixture-secret-only'}
        values.update(extra)
        self.config.write_text(json.dumps(values))
        self.config.chmod(0o600)

    def test_rejects_unsafe_configuration_without_changing_database(self):
        for field, value in [('default_role', 'admin'),
                             ('redirect_url', 'https://attacker.example/callback'),
                             ('issuer_url', 'https://attacker.example'),
                             ('allow_signup', False), ('use_pkce', False),
                             ('scopes', 'openid profile email https://www.googleapis.com/auth/drive'),
                             ('claim_username', 'email'), ('unknown', 'value')]:
            with self.subTest(field=field):
                self.write_config(**{field: value})
                with self.assertRaises(ValueError):
                    self.module.configure_google(self.config, self.database)
                with sqlite3.connect(self.database) as db:
                    self.assertEqual(db.execute('SELECT * FROM server_config').fetchall(),
                                     [('existing', 'preserved')])
                self.assertEqual(list(self.root.glob('*.backup-*')), [])

    def test_configures_exact_google_flow_and_keeps_consistent_private_backup(self):
        self.write_config()
        backup = self.module.configure_google(self.config, self.database)
        with sqlite3.connect(self.database) as db:
            values = dict(db.execute('SELECT * FROM server_config'))
        self.assertEqual(values['existing'], 'preserved')
        self.assertEqual(values['oidc.client_secret'], 'fixture-secret-only')
        self.assertEqual(values['oidc.default_role'], 'pro')
        self.assertEqual(values['oidc.claim_username'], 'sub')
        self.assertEqual(values['oidc.scopes'], 'openid profile email')
        self.assertEqual(values['oidc.use_pkce'], 'true')
        self.assertEqual(values['oidc.allow_signup'], 'true')
        self.assertEqual(values['oidc.redirect_url'],
                         'https://gadesk.grupoamayo.com/api/oidc/callback')
        with sqlite3.connect(backup) as db:
            self.assertEqual(db.execute('SELECT * FROM server_config').fetchall(),
                             [('existing', 'preserved')])
        self.assertEqual(backup.stat().st_mode & 0o777, 0o600)

    def test_refuses_public_secret_file_and_nonexistent_database(self):
        self.write_config()
        self.config.chmod(0o644)
        with self.assertRaises(ValueError):
            self.module.configure_google(self.config, self.database)
        self.config.chmod(0o600)
        absent = self.root / 'absent.sqlite3'
        with self.assertRaises(ValueError):
            self.module.configure_google(self.config, absent)
        self.assertFalse(absent.exists())


if __name__ == '__main__':
    unittest.main()
