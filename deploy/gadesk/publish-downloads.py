#!/usr/bin/env python3
"""Generate a manifest for verified installers already copied into the web root."""
import hashlib
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
assets = [
    ('android', 'GADESK-1.5.1-android-arm64.apk', 'Descargar APK'),
    ('macos', 'GADESK-1.5.1-macos-arm64.dmg', 'Descargar DMG'),
    ('macos', 'GADESK-1.5.1-macos-arm64.pkg', 'Descargar PKG'),
    ('windows', 'GADESK-1.5.1-x86_64-install.exe', 'Descargar EXE'),
    ('windows', 'GADESK-1.5.1-x86_64.msi', 'Descargar MSI'),
]
manifest, checksums = [], []
for platform, name, label in assets:
    path = root / name
    if not path.is_file():
        continue
    digest = hashlib.file_digest(path.open('rb'), 'sha256').hexdigest()
    manifest.append(dict(platform=platform, file=name, label=label,
                         size_mb=round(path.stat().st_size / 1024**2, 1), sha256=digest))
    checksums.append(f'{digest}  {name}\n')
for name, data in [('downloads.json', json.dumps(manifest, indent=2) + '\n'),
                   ('SHA256SUMS', ''.join(checksums))]:
    temporary = root / (name + '.tmp')
    temporary.write_text(data)
    temporary.chmod(0o644)
    temporary.replace(root / name)
print(f'Published {len(manifest)} available installers')
