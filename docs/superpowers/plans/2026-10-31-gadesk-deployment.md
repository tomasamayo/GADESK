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

- [ ] Build ARM64 native library and Android app with pinned dependencies.
- [ ] Sign with a private project keystore preserved outside version control/public files.
- [ ] Verify signature, application ID, label and embedded ABI.

### Task 4: Produce macOS and Windows installers

**Files:** deploy/gadesk/package-macos.sh, .github/workflows/gadesk-windows.yml.

- [x] Build GADESK macOS release and package an Apple Silicon DMG and PKG.
- [x] Run an isolated Windows x64 build with artifact upload only (build in progress).
- [ ] Package GADESK EXE/MSI with consistent runtime, file and service names.
- [ ] Verify outputs and report certificate/OS test availability honestly.

### Task 5: Publish and final review

**Files:** deploy/gadesk/downloads/index.html, manifest/checksums, deployment notes.

- [ ] Publish only completed installers, public configuration, checksums and corresponding source.
- [ ] Check HTTPS download status, sizes and SHA256 against local originals.
- [x] Review all existing-code changes for necessity and regressions; fixed ad hoc signing and shared-proxy relay connection ceiling.
- [ ] Record completed deliverables and any concrete external blockers.
