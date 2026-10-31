# GADESK Deployment Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement each task, maintaining a local progress ledger.

**Goal:** Deploy the user's GADESK server and publish verified platform installers.

**Architecture:** GADESK Rust/Flutter clients use WSS on the existing HTTPS virtual host. A pinned Go-only BetterDesk backend supports host registration and encrypted relay over port 443. Original OSS server data is retained for rollback.

**Tech Stack:** Rust 1.81, Flutter 3.24.5, RustDesk server 1.1.16, Docker Compose, nginx, Android SDK/NDK, Windows build runner.

**Spec:** ../specs/2026-10-31-gadesk-deployment-design.md

## Global Constraints

- Domain `gadesk.grupoamayo.com`, public IP `190.234.243.119`.
- Public root `/www/wwwroot/GA/DATAX/GADESK`; private data under `/opt/gadesk`.
- Brand GADESK; application ID `com.grupoamayo.gadesk`.
- Preserve shared submodule, bridge ABI, JNI package and native-library names.
- Existing root browser terminal is authorized; SSH credentials are unavailable.
- No private key or credentials in published artifacts or source.

## Review Focus

- NAT/firewall reachability must match actual publicly reachable services.
- A private server outage must not silently select a public RustDesk server.
- GADESK updates must not install upstream RustDesk over the branded client.
- Platform package names must match runtime installation/service conventions.
- Source downloads and build payloads must exclude private signing/server keys.

### Task 1: Deploy and verify the server

**Files:** deploy/gadesk/compose.yml, deploy/gadesk/deploy-server.sh

- [x] Inspect current virtual host, resources, ports and firewall.
- [x] Prepare pinned server services with private persisted data and public key export.
- [x] Apply through the authorized terminal, preserving unrelated services.
- [x] Verify public reachability: raw ports fail behind inaccessible router; WSS443 passes registration, signature and bidirectional encrypted relay checks.

### Task 2: Bind and brand the clients

**Files:** src/gadesk.rs, src/lib.rs, src/common.rs, res/gadesk, selected platform metadata/assets.

- [x] Add isolated startup configuration using the server's real public key.
- [x] Set GADESK runtime name, defaults and update controls using existing config maps.
- [x] Update visible product labels/icons and platform application IDs while preserving internal ABI names.
- [x] Build the Mac client; verify GADESK profile, WSS endpoint and green Listo registration.

### Task 3: Produce signed Android APK

**Files:** deploy/gadesk/build-android.sh, private ignored signing configuration.

- [x] Build ARM64 native library and Android app with pinned dependencies.
- [x] Sign with a private project keystore preserved outside version control/public files.
- [x] Verify signature, application ID, label and embedded ABI; downloaded APK verifies with v1/v2 signatures and all five embedded brand assets match the supplied vector mark.

### Task 4: Produce macOS and Windows installers

**Files:** deploy/gadesk/package-macos.sh, .github/workflows/gadesk-windows.yml.

- [x] Build GADESK macOS release and package an Apple Silicon DMG and PKG.
- [x] Run an isolated Windows x64 build with artifact upload only; new-logo run 41247268033 passed.
- [x] Package GADESK EXE/MSI with consistent runtime, file and service names.
- [x] Verify outputs: CI version probe, x64 PE/MSI metadata, artifact and installer hashes passed. Mac ad hoc/unsigned PKG, Windows unsigned; no interactive Windows or physical Android installation test.

### Task 5: Publish and final review

**Files:** deploy/gadesk/downloads/index.html, manifest/checksums, deployment notes.

- [x] Publish all five verified installers, public configuration, SVG, checksums and corresponding source.
- [x] Check HTTPS download status, sizes and SHA256 against local originals for all installers and source.
- [x] Review all existing-code changes for necessity and regressions; fixed ad hoc signing and shared-proxy relay connection ceiling.
- [x] Record completed deliverables and limitations; no external blocker remains for artifact delivery.

## Supplied brand mark update

The user supplied `GA-LOGO.png` and requested vectorization. The editable master
is `res/gadesk/brand-mark.svg`, preserving the teal/gray geometry and registered
mark. Platform icons, wordmarks and tray assets were regenerated from it.
Mac native/Flutter release and DMG/PKG verification passed; its UI shows the new
mark and Listo. Android and Mac packages, SVG and matching source are published
and their HTTPS download hashes match. Windows run `41247268033`, source
`10b38db0151d64091b1fa61c6f42051c7bf63fa4`, produced the verified new-logo
EXE and MSI. The earlier old-logo build remains unpublished.

All five installers are published at `https://gadesk.grupoamayo.com/` and their
download hashes match. The SVG is available as `GADESK-logo.svg`. Backend WSS
registration and encrypted relay were exercised with 52 protocol checks, and
the Mac GUI shows the new logo and Listo. Android signing/identity/ABI/assets
and Windows CI version/PE/MSI metadata were verified. Physical Android and
interactive Windows installation/control sessions were not tested. macOS
requires Apple Silicon and macOS 12.3+, is ad hoc signed and not notarized;
the PKG and Windows installers have no publisher signature.
