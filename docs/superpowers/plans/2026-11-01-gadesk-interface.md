# GADESK Interface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reproduce the approved light GADESK mockup on desktop and adapt its visual language to Android, delivering updated installers.

**Architecture:** Add small presentation widgets and apply them to the existing home/connection/peer views. Keep live models, callbacks and remote-session implementation; scope visual changes to GADESK and preserve explicit theme preferences.

**Tech Stack:** Flutter 3.24.5, existing flutter_svg/assets, Rust native bridge, Android SDK/NDK builder, local macOS build, existing GitHub Windows workflow.

**Spec:** `docs/superpowers/specs/2026-11-01-gadesk-google-and-interface-design.md` (approved); account dialog from `2026-11-01-gadesk-google.md` Task 3.

## Global Constraints

- Preserve existing logo and RustDesk notices; use actual IDs/passwords/status, never mockup sample data.
- White/blue-tinted surfaces, turquoise details, blue Connect button, rounded cards and desktop sidebar like the first reference image.
- Default GADESK to light only when no explicit preference exists; retain dark/system selections.
- Preserve connecting, copying, regenerating passwords, permission actions, tabs/search/filter/menu and keyboard focus.
- No FFI generation, `libs/hbb_common`, native protocol, JNI/library/app identity changes.
- APK updates retain signing key and increment build number; keep published installers until replacements are verified.

## Review Focus

- Small desktop window or large text must scroll/wrap without hiding the Connect action (Tasks 1–2).
- Incoming-only/outgoing-only modes must retain their previous allowed controls (Task 2).
- Permission denial must retain the real permission CTA and never falsely show granted/ready (Task 2).
- Android keyboard and portrait/landscape must keep the input/button reachable (Task 3).
- Explicit dark/system theme choices and non-GADESK applications must retain behavior (Tasks 1–3).

---

### Task 1: GADESK presentation components

**Files:** Create `flutter/lib/common/widgets/gadesk_surface.dart`, `flutter/lib/common/widgets/gadesk_empty_state.dart`, `flutter/test/gadesk_surface_test.dart`; modify `flutter/lib/common.dart` only for the no-preference GADESK theme default if necessary.

**Interfaces:** `GadeskSurface({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(20), bool accent = false})`; `GadeskEmptyState({required String title, required String description, required IconData icon})`. Both use Theme brightness and existing vector logo assets. They contain no FFI/model access. Use existing application name and theme option logic at integration sites.

- [ ] Write tests for card content visibility at 360px width, 200% text scale and dark theme; theme-preference test covers empty/light/dark/system and non-GADESK. Confirm failures before adding the implementation.
- [ ] Add minimal reusable surface, empty-state vector composition and semantic labels. Use native Flutter shapes/gradients; do not generate bitmap logos or add a new rendering dependency. Set light fallback only for GADESK with empty preference.
- [ ] Run focused Flutter tests and analyzer; commit.

### Task 2: Desktop home matching the mockup

**Files:** Modify `flutter/lib/desktop/pages/desktop_home_page.dart`, `flutter/lib/desktop/pages/connection_page.dart`, `flutter/lib/common/widgets/peer_tab_page.dart`; create `flutter/test/gadesk_home_layout_test.dart` for presentation behavior that can be exercised without initializing native models.

**Interfaces:** Existing `buildIDBoard`, `buildPasswordBoard2`, `buildHelpCards`, `_buildRemoteIDTextField`, `PeerTabPage` retain their model inputs and callbacks. Add GADESK-only presentation branches that consume Task 1 surfaces; avoid refactoring upstream/non-GADESK layout.

- [ ] Capture baseline desktop screenshots at the mockup ratio and a narrow window. Add one behavior-focused layout test for the new shell: sidebar and primary action visible/wrapping at supported widths and large text, using actual presentation widgets rather than a new test-only production hook. Confirm initial failure.
- [ ] Apply logo/header/notice order, pale sidebar and identity/password/permission cards. Reuse copy, regenerate and settings handlers. Keep incoming-only/outgoing-only controls and service warning behavior.
- [ ] Apply a wide remote-control card, blue Connect button and existing connection-type menu, preserving ID autocomplete/Enter action. Style existing peer tabs/selected states; add empty-state presentation only when the existing selected tab is actually empty. Keep toolbar/filter/search and peer actions visible.
- [ ] Run focused tests/analyzer and launch the actual macOS build for visual comparison. Exercise copying, password refresh, permissions CTA, tab changes, Enter-to-connect and a failed connection. Check narrow/large text, dark mode, denied permissions and both directional client modes. Record actual unavailable modes instead of claiming unrun tests.
- [ ] Inspect diff minimization; commit only home/connection presentation changes.

### Task 3: Android visual adaptation

**Files:** Modify `flutter/lib/mobile/pages/home_page.dart`, `flutter/lib/mobile/pages/connection_page.dart`, `flutter/lib/mobile/pages/server_page.dart` and account entry styling in `settings_page.dart` only where necessary; extend focused surface/layout tests for mobile.

**Interfaces:** Existing mobile navigation, server permission widgets, remote-ID controller, PeerTabPage and login entry remain authoritative. Consume Task 1 presentation widgets and Google panel from the account plan; no new account or connection state store.

- [ ] Add the mobile constraint case to focused layout tests: input/action accessible at 360px width with keyboard-equivalent reduced height and large text; confirm failure against the desktop-only presentation.
- [ ] Apply brand colors/logo/cards using scrolling mobile sections and existing navigation. Preserve Android accessibility/screen-capture permission lifecycle and keyboard handling; do not squeeze the desktop sidebar into mobile.
- [ ] Run focused tests/analyzer. Build an APK candidate and verify cold startup, navigation, keyboard/rotation, real permissions presentation and Google browser-return on the connected Samsung if available; otherwise report the missing device test. Commit.

### Task 4: Platform packages and verified publication

**Files:** `flutter/pubspec.yaml`, `deploy/gadesk/publish-downloads.py`, `deploy/gadesk/ANDROID.md`, README.md and GOOGLE.md; build scripts/workflow only for concrete failures caused by this change. New ignored candidate outputs under `.local/gadesk` and private VPS build folders.

**Interfaces:** Higher Android version code with original certificate; existing macOS bundle/application ID; existing Windows workflow. Publish manifest entries only for verified files and ship corresponding source including pinned submodule and backend patch/license.

- [ ] Run focused regression tests and native macOS build; package DMG/PKG and validate bundle/signature/architecture. Build signed ARM64 APK on VPS and inspect application ID, increasing version, certificate, native ABI and cold startup on emulator/Samsung.
- [ ] Trigger existing Windows workflow for the actual source revision; inspect successful build, x64 metadata, artifact checksums and available runtime verification. Do not imply a Windows device test when none ran.
- [ ] Finish live Google tests from account plan when owner configuration is ready. Record any dependency still pending and keep Google explicitly unavailable until it succeeds.
- [ ] Prepare versioned APK/DMG/PKG/EXE/MSI candidates, matching source archive and checksums. Validate downloaded bytes, then atomically promote public manifest and compatible old aliases. Recheck all five download links and public API behavior.
- [ ] Report exact changed files/runtime paths, tests performed and remaining external/signing limitations. Commit and push the reviewed result, leaving a clean working tree and private rollback notes.

## Self-review

Desktop/mobile visuals, real controls, responsiveness, theme choices, platform artifacts and corresponding source all have tasks. Google setup remains in the companion plan; both can be tested independently before final combined release. No remote session, advanced settings or transfer redesign is included.
