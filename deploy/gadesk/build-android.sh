#!/usr/bin/env bash
set +x
set -euo pipefail
umask 077

if [[ ${1:-} == --help ]]; then
    cat <<'USAGE'
Build the GADESK Android ARM64 release from source on x86_64 Linux.
Run inside android-builder.Dockerfile's image; see ANDROID.md.

GADESK_BUILD_ROOT        Private toolchains/caches/output root (/opt/gadesk/build)
GADESK_SOURCE_DIR        Complete source payload ($GADESK_BUILD_ROOT/source)
GADESK_BUILD_JOBS        Native build parallelism (8)
GADESK_CARGO_TOOLCHAIN   Cargo executable: 1.81.0 or stable (1.81.0)
GADESK_SOURCE_REVISION   Revision recorded for a source payload without .git

Signing credentials are generated once under $GADESK_BUILD_ROOT/secrets.
Copy previously accepted Android SDK licenses to $GADESK_BUILD_ROOT/android-licenses.
An existing Mac Cargo git/registry cache can be seeded in $GADESK_BUILD_ROOT/cargo;
set GADESK_CARGO_TOOLCHAIN=stable to preserve modern cache hashing with RUSTC 1.81.
The source payload must include flutter/pubspec.lock and res/gadesk/bridge-master.zip.
No downloads or build steps run for --help.
USAGE
    exit 0
fi
if [[ $# -ne 0 ]]; then
    printf 'Unknown argument: %s\n' "$1" >&2
    exit 2
fi

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || fail 'Use an x86_64 Linux builder.'

build_root=$(realpath -m "${GADESK_BUILD_ROOT:-/opt/gadesk/build}")
source_dir=$(realpath -m "${GADESK_SOURCE_DIR:-$build_root/source}")
[[ -f "$source_dir/Cargo.lock" && -f "$source_dir/libs/hbb_common/Cargo.toml" ]] ||
    fail "Source payload or hbb_common submodule missing: $source_dir"
[[ -f "$source_dir/res/gadesk/bridge-master.zip" ]] || fail 'Missing res/gadesk/bridge-master.zip.'
[[ -f "$source_dir/flutter/pubspec.lock" ]] || fail 'Missing flutter/pubspec.lock.'
[[ ${GADESK_CARGO_TOOLCHAIN:-1.81.0} == 1.81.0 || ${GADESK_CARGO_TOOLCHAIN:-1.81.0} == stable ]] ||
    fail 'GADESK_CARGO_TOOLCHAIN must be 1.81.0 or stable.'
[[ ${GADESK_BUILD_JOBS:-8} =~ ^[1-9][0-9]*$ ]] || fail 'GADESK_BUILD_JOBS must be a positive integer.'

toolchains="$build_root/toolchains"
secrets="$build_root/secrets"
case "$secrets/" in "$source_dir/"*) fail 'Secrets must be outside the source payload.' ;; esac
mkdir -p "$toolchains" "$secrets" "$build_root/output"
chmod 700 "$secrets"
export CARGO_HOME="$build_root/cargo"
export RUSTUP_HOME="$build_root/rustup"
export PUB_CACHE="$build_root/pub-cache"
export GRADLE_USER_HOME="$build_root/gradle"
export ANDROID_HOME="$toolchains/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/28.2.13676358"
export ANDROID_NDK_ROOT="$ANDROID_NDK_HOME"
export FLUTTER_SUPPRESS_ANALYTICS=true
export CI=true
export CARGO_BUILD_JOBS="${GADESK_BUILD_JOBS:-8}"
export VCPKG_MAX_CONCURRENCY="$CARGO_BUILD_JOBS"
export CARGO_NET_GIT_FETCH_WITH_CLI=true
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH="$CARGO_HOME/bin:$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$toolchains/flutter/bin:$PATH"
export RUSTUP_TOOLCHAIN="${GADESK_CARGO_TOOLCHAIN:-1.81.0}"

if [[ ! -x "$CARGO_HOME/bin/rustup" ]]; then
    curl --fail --location --retry 3 https://sh.rustup.rs -o "$toolchains/rustup-init.sh"
    sh "$toolchains/rustup-init.sh" -y --no-modify-path --profile minimal --default-toolchain 1.81.0
fi
rustup toolchain install 1.81.0 --profile minimal
rustup target add aarch64-linux-android --toolchain 1.81.0
if [[ "$RUSTUP_TOOLCHAIN" == stable ]]; then
    rustup toolchain install stable --profile minimal
fi
export RUSTC
RUSTC=$(rustup which --toolchain 1.81.0 rustc)
export RUSTDOC
RUSTDOC=$(rustup which --toolchain 1.81.0 rustdoc)
if [[ ! -x "$CARGO_HOME/bin/cargo-ndk" ]] || [[ $(cargo ndk --version) != 'cargo-ndk 3.1.2' ]]; then
    cargo install cargo-ndk --version 3.1.2 --locked --force
fi

flutter_commit=dec2ee5c1f98f8e84a7d5380c05eb8a3d0a81668
if [[ ! -d "$toolchains/flutter/.git" ]]; then
    git clone --depth 1 --branch 3.24.5 https://github.com/flutter/flutter.git "$toolchains/flutter"
fi
[[ $(git -C "$toolchains/flutter" rev-parse HEAD) == "$flutter_commit" ]] || fail 'Flutter cache is not 3.24.5.'
flutter_patch="$source_dir/.github/patches/flutter_3.24.4_dropdown_menu_enableFilter.diff"
if git -C "$toolchains/flutter" apply --check "$flutter_patch" 2>/dev/null; then
    git -C "$toolchains/flutter" apply "$flutter_patch"
else
    git -C "$toolchains/flutter" apply --reverse --check "$flutter_patch"
fi
flutter config --no-analytics
flutter precache --android

if [[ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]]; then
    curl --fail --location --retry 3 \
        https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip \
        -o "$toolchains/android-commandlinetools.zip"
    mkdir -p "$ANDROID_HOME/cmdline-tools"
    unzip -q "$toolchains/android-commandlinetools.zip" -d "$ANDROID_HOME/cmdline-tools"
    mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
fi
if [[ -d "$build_root/android-licenses" ]]; then
    mkdir -p "$ANDROID_HOME/licenses"
    cp -a "$build_root/android-licenses/." "$ANDROID_HOME/licenses/"
fi
sdkmanager 'platform-tools' 'platforms;android-36' 'build-tools;36.0.0' 'ndk;28.2.13676358'

export VCPKG_ROOT="$toolchains/vcpkg"
export VCPKG_DEFAULT_TRIPLET=arm64-android
export VCPKG_DEFAULT_HOST_TRIPLET=x64-linux
export VCPKG_OVERLAY_PORTS="$source_dir/res/vcpkg"
export VCPKG_OVERLAY_TRIPLETS="$source_dir/res/vcpkg-triplets"
vcpkg_commit=9e593bb18ea69cc5095e012465dcd675a822ed0d
if [[ ! -d "$VCPKG_ROOT/.git" ]]; then
    git init "$VCPKG_ROOT"
    git -C "$VCPKG_ROOT" remote add origin https://github.com/microsoft/vcpkg.git
    git -C "$VCPKG_ROOT" fetch --depth 1 origin "$vcpkg_commit"
    git -C "$VCPKG_ROOT" checkout --detach FETCH_HEAD
fi
[[ $(git -C "$VCPKG_ROOT" rev-parse HEAD) == "$vcpkg_commit" ]] || fail 'vcpkg cache uses another revision.'
if [[ ! -x "$VCPKG_ROOT/vcpkg" ]]; then
    "$VCPKG_ROOT/bootstrap-vcpkg.sh" -disableMetrics
fi

cd "$source_dir"
unzip -oq res/gadesk/bridge-master.zip -d .
for bridge in src/bridge_generated.rs src/bridge_generated.io.rs \
    flutter/lib/generated_bridge.dart flutter/lib/generated_bridge.freezed.dart; do
    [[ -s "$bridge" ]] || fail "Bridge archive did not supply $bridge"
done
./flutter/build_android_deps.sh arm64-v8a
# cargo-ndk 3.1.2 configures C/C++ compilation, while bindgen's host libclang
# needs an explicit Android sysroot for cross-target system headers.
android_sysroot="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
export BINDGEN_EXTRA_CLANG_ARGS_aarch64_linux_android="--sysroot=$android_sysroot -isystem $android_sysroot/usr/include/aarch64-linux-android -D__ANDROID_API__=21"
cargo ndk --platform 21 --target aarch64-linux-android \
    build --locked --release --features flutter,hwcodec
jni_dir=flutter/android/app/src/main/jniLibs/arm64-v8a
mkdir -p "$jni_dir"
cp target/aarch64-linux-android/release/liblibrustdesk.so "$jni_dir/librustdesk.so"
cp "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so" "$jni_dir/"

keystore="$secrets/gadesk-release.jks"
password_file="$secrets/gadesk-release.password"
if [[ -f "$keystore" ]]; then
    [[ -s "$password_file" ]] || fail 'Existing signing key requires its original password file.'
elif [[ -e "$password_file" ]]; then
    fail 'Password file exists without its signing key; restore the matching key.'
else
    openssl rand -hex 32 > "$password_file"
    chmod 600 "$password_file"
    export GADESK_KEY_PASSWORD
    GADESK_KEY_PASSWORD=$(cat "$password_file")
    keytool -genkeypair -noprompt -keystore "$keystore" -storetype JKS \
        -alias gadesk -keyalg RSA -keysize 3072 -validity 10000 \
        -dname 'CN=GADESK, OU=Software, O=Grupo Amayo, C=PE' \
        -storepass:env GADESK_KEY_PASSWORD -keypass:env GADESK_KEY_PASSWORD
    unset GADESK_KEY_PASSWORD
fi
chmod 600 "$keystore" "$password_file"
key_properties="$source_dir/flutter/android/key.properties"
[[ ! -e "$key_properties" ]] || fail 'Existing android/key.properties would be overwritten; remove it from the build payload first.'
trap 'rm -f "$key_properties"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
{
    printf 'storeFile=%s\nkeyAlias=gadesk\n' "$keystore"
    printf 'storePassword=%s\nkeyPassword=%s\n' "$(cat "$password_file")" "$(cat "$password_file")"
} > "$key_properties"

cd flutter
flutter pub get --enforce-lockfile
flutter build apk --release --target-platform android-arm64 --split-per-abi
apk=build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
android_tools="$ANDROID_HOME/build-tools/36.0.0"
"$android_tools/apksigner" verify --verbose --print-certs "$apk"
badging=$("$android_tools/aapt" dump badging "$apk")
[[ "$badging" == *"package: name='com.grupoamayo.gadesk'"* ]] || fail 'APK application ID is incorrect.'
[[ "$badging" == *"application-label:'GADESK'"* ]] || fail 'APK application label is incorrect.'
[[ $(printf '%s\n' "$badging" | sed -n '/^native-code:/p') == "native-code: 'arm64-v8a'" ]] || fail 'APK is not ARM64 only.'
unzip -Z1 "$apk" | grep -x 'lib/arm64-v8a/librustdesk.so' >/dev/null

output="$build_root/output/GADESK-1.5.1-android-arm64.apk"
cp "$apk" "$output"
chmod 644 "$output"
(cd "$build_root/output" && sha256sum "$(basename "$output")") > "$output.sha256"
{
    printf 'GADESK Android ARM64 source build\nSource revision: %s\n' \
        "${GADESK_SOURCE_REVISION:-$(git -C "$source_dir" rev-parse HEAD 2>/dev/null || printf 'source payload; see corresponding source archive')}"
    "$RUSTC" --version
    cargo --version
    flutter --version
    printf 'vcpkg: %s\nNDK: 28.2.13676358 (r28c)\n' "$vcpkg_commit"
    sha256sum "$source_dir/res/gadesk/bridge-master.zip"
    "$android_tools/apksigner" verify --print-certs "$output"
    printf '%s\n' "$badging"
} > "$build_root/output/android-build-info.txt"
chmod 644 "$output.sha256" "$build_root/output/android-build-info.txt"
printf 'Verified APK: %s\n' "$output"
