#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'HELP'
Usage: deploy/gadesk/package-macos.sh [RustDesk.app]

Package the completed macOS ARM64 Release build as GADESK 1.5.1.
The default input is flutter/build/macos/Build/Products/Release/RustDesk.app.
The native service must already exist at target/release/service.

Outputs: target/gadesk-macos/GADESK.app and installers/{DMG,PKG,SHA256SUMS}.
The app is ad hoc signed, the PKG is unsigned, and neither is notarized.
This script does not install the app or register launchd services.
HELP
    exit 0
fi

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
[[ $# -le 1 ]] || fail 'Expected at most one source application path.'
[[ $(uname -s) == Darwin ]] || fail 'Run this script on macOS.'
export LC_ALL=C
umask 077

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_app=${1:-"$repo_root/flutter/build/macos/Build/Products/Release/RustDesk.app"}
service="$repo_root/target/release/service"
stage_dir="$repo_root/target/gadesk-macos"
app="$stage_dir/GADESK.app"
installers="$stage_dir/installers"
version=1.5.1
bundle_id=com.grupoamayo.gadesk
plist_buddy=/usr/libexec/PlistBuddy

for tool in ditto codesign hdiutil pkgbuild pkgutil plutil lipo lsbom xmllint shasum; do
    command -v "$tool" >/dev/null || fail "Missing native tool: $tool"
done
[[ -x "$source_app/Contents/MacOS/RustDesk" ]] || fail "Missing source executable: $source_app/Contents/MacOS/RustDesk"
[[ -x "$service" ]] || fail "Missing release service: $service"
[[ $(lipo -archs "$source_app/Contents/MacOS/RustDesk") == arm64 ]] || fail 'The source app must be ARM64 only.'
[[ $(lipo -archs "$service") == arm64 ]] || fail 'The release service must be ARM64 only.'
[[ $("$plist_buddy" -c 'Print :CFBundleShortVersionString' "$source_app/Contents/Info.plist") == "$version" ]] || fail "The source app must be version $version."

mkdir -p "$installers"
work_dir=$(mktemp -d "$stage_dir/packaging.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT
rm -rf "$app"
ditto "$source_app" "$app"
mv "$app/Contents/MacOS/RustDesk" "$app/Contents/MacOS/GADESK"
ditto "$service" "$app/Contents/MacOS/service"
info="$app/Contents/Info.plist"
plutil -replace CFBundleExecutable -string GADESK "$info"
plutil -replace CFBundleName -string GADESK "$info"
plutil -replace CFBundleDisplayName -string GADESK "$info"
plutil -replace CFBundleIdentifier -string "$bundle_id" "$info"
plutil -lint "$info"

bash "$repo_root/.github/scripts/sign-macos-app.sh" \
    "$app" - "$repo_root/flutter/macos/Runner/Release.entitlements"

for key in CFBundleExecutable CFBundleName CFBundleDisplayName; do
    [[ $("$plist_buddy" -c "Print :$key" "$info") == GADESK ]] || fail "Incorrect staged $key."
done
[[ $("$plist_buddy" -c 'Print :CFBundleIdentifier' "$info") == "$bundle_id" ]] || fail 'Incorrect staged bundle identifier.'
[[ $("$app/Contents/MacOS/GADESK" --version) == "$version" ]] || fail 'The staged executable reports an unexpected version.'
[[ $(lipo -archs "$app/Contents/MacOS/GADESK") == arm64 ]] || fail 'The staged executable is not ARM64 only.'
codesign --verify --deep --strict --verbose=2 "$app"

dmg_root="$work_dir/dmg"
mkdir "$dmg_root"
chmod 0755 "$dmg_root"
ditto "$app" "$dmg_root/GADESK.app"
ln -s /Applications "$dmg_root/Applications"
dmg="$installers/GADESK-$version-macos-arm64.dmg"
hdiutil create -volname GADESK -srcfolder "$dmg_root" -format UDZO -ov "$dmg"
hdiutil verify "$dmg"

pkg_root="$work_dir/pkg-root"
mkdir -p "$pkg_root/Applications"
chmod 0755 "$pkg_root/Applications"
ditto "$app" "$pkg_root/Applications/GADESK.app"
components="$work_dir/components.plist"
pkgbuild --analyze --root "$pkg_root" "$components"
index=0
while "$plist_buddy" -c "Print :$index:RootRelativeBundlePath" "$components" >/dev/null 2>&1; do
    plutil -replace "$index.BundleIsRelocatable" -bool false "$components"
    index=$((index + 1))
done
[[ $index -gt 0 ]] || fail 'pkgbuild did not identify the application bundle.'
pkg="$installers/GADESK-$version-macos-arm64.pkg"
pkgbuild --root "$pkg_root" --component-plist "$components" \
    --identifier "$bundle_id" --version "$version" --install-location / \
    --ownership recommended "$pkg"

expanded="$work_dir/pkg-expanded"
pkgutil --expand-full "$pkg" "$expanded"
[[ $(stat -f '%Lp' "$expanded/Payload/Applications") == 755 ]] || fail 'The PKG Applications directory must have mode 0755.'
package_info="$expanded/PackageInfo"
[[ $(xmllint --xpath 'string(/pkg-info/@identifier)' "$package_info") == "$bundle_id" ]] || fail 'Incorrect PKG identifier.'
[[ $(xmllint --xpath 'string(/pkg-info/@version)' "$package_info") == "$version" ]] || fail 'Incorrect PKG version.'
[[ $(xmllint --xpath 'string(/pkg-info/@install-location)' "$package_info") == / ]] || fail 'Incorrect PKG installation root.'
[[ $(xmllint --xpath 'count(/pkg-info/relocate/bundle)' "$package_info") == 0 ]] || fail 'The PKG contains a relocatable application.'
lsbom -s "$expanded/Bom" > "$work_dir/pkg-bom.txt"
grep -Fx './Applications/GADESK.app/Contents/MacOS/GADESK' "$work_dir/pkg-bom.txt" >/dev/null || fail 'The PKG BOM has an incorrect application install path.'
[[ -x "$expanded/Payload/Applications/GADESK.app/Contents/MacOS/service" ]] || fail 'The PKG is missing the service executable.'
codesign --verify --deep --strict --verbose=2 "$expanded/Payload/Applications/GADESK.app"
pkgutil --check-signature "$pkg" > "$work_dir/pkg-signature.txt" 2>&1 || true
cat "$work_dir/pkg-signature.txt"
grep -F 'Status: no signature' "$work_dir/pkg-signature.txt" >/dev/null || fail 'Unexpected PKG signing status.'

(
    cd "$installers"
    shasum -a 256 "$(basename "$dmg")" "$(basename "$pkg")" > SHA256SUMS
    shasum -a 256 -c SHA256SUMS
)
printf 'Created %s and %s\nApp: ad hoc signed. PKG: unsigned. Not notarized.\n' "$dmg" "$pkg"
