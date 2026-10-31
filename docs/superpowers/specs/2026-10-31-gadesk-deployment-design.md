# GADESK deployment

## Request and authorization

The user requests deploying the complete GADESK service to their open aaPanel
server and producing Android, macOS and Windows installers. They specified
`gadesk.grupoamayo.com`, `/www/wwwroot/GA/DATAX/GADESK`, and the GADESK brand.
The existing authenticated root terminal is the deployment entry point.

## Delivery

- RustDesk OSS signaling and relay services, pinned to server 1.1.16.
- Router-independent HTTPS/WSS transport through the existing public port 443.
- HTTPS download directory at the provided domain, with artifact checksums,
  public client configuration and corresponding source archive.
- GADESK clients using their own profile and the supplied server public key.
- Android ARM64 release APK, macOS Apple Silicon application/DMG, Windows x64
  installer. Platform and signing limitations must be stated accurately.

## Approach

Use the existing Rust/Flutter client and official server binaries/container;
do not build a different remote desktop protocol or use the vendor's paid
custom-client signing mechanism. Native server services and Docker both fit;
prefer Docker Compose where the host supports it. Data and the server private
key live under `/opt/gadesk`, outside the public website root. Only the public
key belongs in clients and the download directory.

Add project-owned branding configuration in the client crate with a thin
startup hook, keeping the shared submodule and FFI signatures unchanged.
Keep internal Cargo, Dart, JNI and native-library names compatible. Use
`com.grupoamayo.gadesk` as the Android application ID and macOS bundle ID.
Disable stock application updates in GADESK so they cannot replace this build
with an upstream RustDesk client.

Build macOS locally using the verified toolchains. Android can compile on this
Mac or on the Linux server depending on available storage. Windows requires a
Windows runner; GitHub browser sign-in is pending. No signing certificates were
provided: use an owned Android key, local ad-hoc macOS signing and an unsigned
Windows package unless a trusted signing identity becomes available.

## Verification

Check containers/services and persistence; TCP and UDP reachability from outside
the host; correct DNS and HTTPS download responses. Check configured host/key in
the GADESK process and its registration with the server. Verify APK application
ID/signature, macOS architecture/signature/DMG mounting and Windows package
metadata/contents. Record any unavailable device or Windows installation test.

## Network constraint discovered during deployment

The original OSS services are healthy, but their native ports are not reachable
through the site's router. The user confirmed they cannot access that router.
Native RustDesk 1.5.1 supports WSS; official OSS server 1.1.16 and master reject
host registration on TCP/WebSocket. A plain WebSocket reverse proxy is therefore
insufficient for controlled devices.

Validate the compatible BetterDesk Go signaling/relay backend at source commit
`eb84feff61c25595e326294fccd13e27ccd14a29`, building only its server Dockerfile.
Reuse copies of the existing Ed25519 key pair, preserve the old server/database
for rollback, and keep the new database private. Publish backend WebSocket ports
only on localhost, behind nginx `/ws/id` and `/ws/relay` on HTTPS 443. Do not
publish its administration API or deploy the unrelated web console. Confirm
native registration and relay behavior before claiming compatibility.

GADESK defaults enable `allow-websocket=Y` and use the HTTPS domain as the API
scheme hint required by the existing client transport selector. This changes
transport configuration only; the FFI and remote-session implementation remain
unchanged.

## Constraints

Preserve existing websites, installed RustDesk, firewall access and private keys.
Never publish signing keys, server private keys, credentials or build secrets.
Preserve upstream notices and include corresponding source with distributed
modified clients. No unrelated refactors or changes to signed custom.txt checks.
