# Building the GADESK Android APK

This builds both the native Rust library and Flutter UI from the supplied source.
It produces an ARM64 APK for Android 5.1/API 22 and newer. Receiving remote input
also depends on Android accessibility capabilities and permissions. No physical
device installation or remote-control test is implied by the packaging checks.

Use the x86_64 Linux server's private `/opt/gadesk/build` directory. The first
build downloads toolchains and native dependencies; allow roughly 15–30 GB and
30–90+ minutes, depending on caches and network. Keep these files outside the
public download directory.

## Source payload and build

Put the complete modified source at `/opt/gadesk/build/source`, including the
contents of `libs/hbb_common`, the checked-in `flutter/pubspec.lock` and
`res/gadesk/bridge-master.zip`.
The archive restores the matching generated bridge files; the build never runs
`flutter_rust_bridge_codegen`. Do not include `.local`, `target`, Flutter build
directories, `key.properties`, signing keys, passwords or other credentials in
the source payload or the published corresponding source archive. A Git source
archive alone does not contain the contents of Git submodules; add hbb_common's
pinned source explicitly when preparing it.

Run from the source directory on the server:

```sh
docker build -f deploy/gadesk/android-builder.Dockerfile \
  -t gadesk-android-builder deploy/gadesk
docker run --rm --cpus=12 --memory=24g \
  -e GADESK_BUILD_JOBS=8 \
  -e GADESK_SOURCE_REVISION=94c321d05ce02ee73304e6cf99187e2d4d96e409 \
  -v /opt/gadesk/build:/opt/gadesk/build \
  gadesk-android-builder
```

Use the revision of the actual payload in `GADESK_SOURCE_REVISION`; that value
records its upstream base and does not certify uncommitted branding changes.
Retain the exact modified corresponding source archive with the APK.

The image only installs Linux prerequisites. The script installs its toolchains
and caches under the mounted build root, without changing the host's toolchains:
Rust 1.81.0, cargo-ndk 3.1.2, Flutter 3.24.5 at
`dec2ee5c1f98f8e84a7d5380c05eb8a3d0a81668` with the upstream dropdown patch,
Android SDK 36/build tools 36.0.0, NDK 28.2.13676358/r28c, and vcpkg
`9e593bb18ea69cc5095e012465dcd675a822ed0d`. Before execution, privately copy the
already accepted license files from the Mac's Android SDK `licenses` directory
to `/opt/gadesk/build/android-licenses`. The script copies those files into the
builder SDK. Any additional license prompt or error requires an explicit
operator decision; the script does not accept licenses automatically. Native
dependencies follow the project's vcpkg manifest and ARM64 Android triplet,
including hardware codec support.

If Cargo 1.81 cannot read a newly cached registry manifest, rerun with
`-e GADESK_CARGO_TOOLCHAIN=stable`. This selects modern Cargo for both the Rust
build and Gradle's `cargo metadata`; the script still explicitly selects Rust
1.81 for `RUSTC` and `RUSTDOC`. The selected Cargo version is recorded in the
build report. Do not update Cargo.lock or substitute dependencies to make the
build resolve.

## Optional existing Cargo source cache

Cargo fetches Git dependencies for other platforms during metadata resolution.
The locked wezterm dependency can fetch large font/rendering submodules that
Android's RustDesk client never uses. A previously validated Cargo source cache
can avoid that download. For this workspace, the Mac's existing wezterm checkout
was already checked against the locked revision for `pty` and `filedescriptor`.
Transfer only the `git` and `registry` directories from that trusted cache into
`/opt/gadesk/build/cargo` before building. For example, create the private transfer
archive on the Mac:

```sh
tar -C /Users/tomas/.cargo -czf /private/tmp/gadesk-cargo-source-cache.tar.gz git registry
```

After privately transferring it, extract on the server:

```sh
install -d -m 700 /opt/gadesk/build/cargo
tar --no-same-owner -xzf /path/to/gadesk-cargo-source-cache.tar.gz \
  -C /opt/gadesk/build/cargo
```

Do not transfer `credentials.toml`, Cargo configuration, installed executables
or compiled outputs. Do not publish this cache archive. Keep its existing Git
metadata intact; do not create `.cargo-ok` markers for unchecked source or edit
locked dependency sources. Without a cache, the script uses Cargo's normal Git
CLI fetch strategy and may require substantially more network time/storage.
When using the Mac's modern Cargo cache, add
`-e GADESK_CARGO_TOOLCHAIN=stable` to the Docker invocation to retain its cache
hashing scheme while keeping the compiler explicitly pinned to Rust 1.81.

## Signing and outputs

On first execution the script generates the project's RSA signing key at
`/opt/gadesk/build/secrets/gadesk-release.jks` and a random password at
`gadesk-release.password` in the same private directory. The directory is mode
0700, both files are mode 0600, and the temporary ignored Android
`key.properties` is removed when the script exits. Back up both secret files
privately. Every future APK update must use the same key and a higher Android
version code. Losing the key prevents updating existing installations in place.
The owned key is not a third-party code-signing identity or Play Store signing.

Outputs under `/opt/gadesk/build/output`:

- `GADESK-1.5.1-android-arm64.apk`
- `GADESK-1.5.1-android-arm64.apk.sha256`
- `android-build-info.txt` with compiler versions, bridge hash, package metadata
  and public signer certificate information.

The script fails unless `apksigner` validates the APK, its application ID is
`com.grupoamayo.gadesk`, its label is `GADESK`, and its ABI is ARM64 with
`librustdesk.so`. Only copy these verified outputs to the public download site.
Preserve Kotlin/JNI namespace `com.carriez.flutter_hbb`, library name
`librustdesk.so`, and `ffi.FFI`; these are independent of the application ID.

Local validation of these automation files consists of `bash -n` and script
argument checks. A successful source build and device test must be recorded
separately after actual execution.
