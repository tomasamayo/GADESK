#!/usr/bin/env python3
"""Generate a manifest for verified installers already copied into the web root."""
import hashlib
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
assets = [
    ('android', 'GADESK-1.5.1-android-arm64-build71.apk', 'Descargar APK'),
    ('macos', 'GADESK-1.5.1-macos-arm64-build71.dmg', 'Descargar DMG'),
    ('macos', 'GADESK-1.5.1-macos-arm64-build71.pkg', 'Descargar PKG'),
    ('windows', 'GADESK-1.5.1-x86_64-build71-install.exe', 'Descargar EXE'),
    ('windows', 'GADESK-1.5.1-x86_64-build71.msi', 'Descargar MSI'),
]
source = root / 'GADESK-1.5.1-build71-source.tar.gz'
missing = [name for _, name, _ in assets if not (root / name).is_file()]
if not source.is_file():
    missing.append(source.name)
if missing:
    sys.exit('Incomplete release; current manifest preserved. Missing: ' + ', '.join(missing))
manifest, checksums = [], []
for platform, name, label in assets:
    path = root / name
    with path.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    manifest.append(dict(platform=platform, file=name, label=label,
                         size_mb=round(path.stat().st_size / 1024**2, 1), sha256=digest))
    checksums.append(f'{digest}  {name}\n')
with source.open('rb') as stream:
    digest = hashlib.file_digest(stream, 'sha256').hexdigest()
checksums.append(f'{digest}  {source.name}\n')
for name, data in [('downloads.json', json.dumps(manifest, indent=2) + '\n'),
                   ('SHA256SUMS', ''.join(checksums))]:
    temporary = root / (name + '.tmp')
    temporary.write_text(data)
    temporary.chmod(0o644)
    temporary.replace(root / name)
print(f'Published {len(manifest)} available installers')
