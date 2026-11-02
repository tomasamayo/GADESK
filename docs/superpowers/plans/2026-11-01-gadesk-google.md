# GADESK Google Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable public Google signup and private account address books in the existing GADESK apps.

**Architecture:** Keep the pinned BetterDesk Go backend and Flutter's existing browser/polling account flow. Apply a reproducible Google-specific backend patch before exposing an explicit client API allowlist through HTTPS; keep administrative APIs private.

**Tech Stack:** Go, pinned BetterDesk `eb84feff61c25595e326294fccd13e27ccd14a29`, standard OIDC verifier library, Flutter 3.24.5, nginx, Docker Compose.

**Spec:** `docs/superpowers/specs/2026-11-01-gadesk-google-and-interface-design.md` (approved by user).

## Global Constraints

- Public signup with Google; scopes `openid profile email`; callback `https://gadesk.grupoamayo.com/api/oidc/callback`.
- Stable identity is Google issuer plus `sub`; no email-prefix matching or automatic linking to local accounts.
- New accounts receive `pro`, never administrator; personal address books remain private.
- Do not change `libs/hbb_common`, regenerate FFI, or change JNI/library/application identities.
- Keep WSS endpoints, relay keys, existing clients and downloads operational until replacements pass checks.
- Google secret stays private on the VPS. No credentials in source, installers, logs or chat.
- Owner completes creation of Google credentials and legal acceptance. No billing activation.

## Review Focus

- Two Google identities with the same email prefix must never resolve to the same account (Task 1).
- An existing local username must not be claimed through first Google login (Task 1).
- A signed token for another client, issuer, nonce or expired session must fail closed (Task 1).
- Cancellation followed by retry must not resume an older login attempt (Task 3).
- An authenticated public user must not see another user's devices or administrative routes (Tasks 1–2).

---

### Task 1: Verified Google identities and account isolation

**Files:** Create `deploy/gadesk/patches/betterdesk-google.patch` and `deploy/gadesk/GOOGLE.md`; patch upstream `betterdesk-server/auth/oidc.go`, new `auth/oidc_google.go`, `auth/oidc_google_test.go`, `api/client_oidc_handlers.go`, `api/client_oidc_handlers_test.go`, `go.mod`, `go.sum`.

**Interfaces:** Consume existing `(*OIDCProvider).ExchangeCode(ctx, code, state) (*OIDCResult, error)` and `(*Server).ensureOIDCUser(result, cfg) (*db.User, string)`. Produce `verifyGoogleIdentity(ctx context.Context, cfg OIDCConfig, rawIDToken, nonce string, userinfo map[string]interface{}) (map[string]interface{}, error)` and stable username `google:<sub>`. Existing non-Google provider paths remain unchanged.

- [ ] Fetch an isolated ignored backend checkout at the exact pin; read its AGENTS instructions if present. Run existing `go test ./auth ./api` in the official Go toolchain image and record baseline failures separately.
- [ ] Add table-driven tests using signed local OIDC/JWKS fixtures and existing httptest helpers: valid Google identity accepted; wrong signature/audience/issuer/expiry/nonce, mismatched UserInfo sub and missing ID token rejected. Test two email prefixes with different sub values, and rejection of a colliding local-auth username. Add two-account API tests for address-book separation and role `pro` denial of server/device enumeration.
- [ ] Run the named new tests; confirm they fail against the pinned code for the intended missing checks.
- [ ] Add a pinned maintained OIDC verifier dependency with its checksums, justified by signature/JWKS validation. Integrate a Google-only verification hook before claims can create accounts; require verified issuer/audience/expiry/nonce, reject UserInfo sub mismatch, derive `google:<sub>`, and reject silent linking to non-OIDC users. Require successful Google UserInfo when using its attributes; never fall back to unverified payloads. Preserve state/PKCE/device binding and the existing single-use result flow. Remove credential-bearing error/log output only along this Google flow.
- [ ] Run new tests and existing auth/API suites, `go vet ./auth ./api`, and inspect the final patch for unrelated changes. Generate `betterdesk-google.patch` including the tests and module sums from the pinned checkout; record upstream pin and patch SHA-256 in GOOGLE.md.
- [ ] Commit the patch and its documentation after checks pass.

### Task 2: Reproducible server deployment and client API routing

**Files:** Modify `deploy/gadesk/deploy-wss.sh`, `deploy/gadesk/compose.wss.yml`, `deploy/gadesk/nginx-wss.conf`; create `deploy/gadesk/configure-google.py`; document in GOOGLE.md and WSS.md.

**Interfaces:** Apply Task 1 patch to a clean pinned checkout using `git apply --check` before build; use a distinct patched image tag. `configure-google.py PRIVATE_CONFIG_JSON PRIVATE_SQLITE_DB` validates Google issuer, callback, `claim_username`, `default_role=pro`, `allow_signup=true`, PKCE and scopes, then updates `oidc.*` with a transactional backup while the backend is stopped. It must not print the secret or accept it as a command-line value.

- [ ] Record the currently failing public GET `/api/login-options` (404). Build a staged container with copied test data and the patched image; no production traffic or real keys in the test fixture.
- [ ] Define and test the exact nginx locations from actual Flutter/native account calls: login-options, OIDC auth/auth-query/callback, logout/currentUser, personal/legacy address books and required account/group compatibility calls. Deny all unlisted API paths. Test expected 401/403 with no token and with a `pro` session, including `/api/users`, `/api/config/*` and `/api/peers` denial. Preserve `/ws/id` and `/ws/relay` blocks.
- [ ] Add only the localhost API mapping required by nginx and exact route locations, with TLS via existing host, no caching of account responses, request limits and correct proxy address. Add patch application and image version to the existing deployment script; retain its validation/rollback behavior.
- [ ] Implement configuration validation and backup; verify an invalid callback/role cannot modify the DB and a valid fixture persists the exact settings without exposing secrets. Use existing Python stdlib and SQLite support, not a new service.
- [ ] Validate shell syntax, `docker compose config`, nginx config and staged HTTP requests; commit. Stage production artifacts privately, but retain the running service until Task 4 deployment gates pass.

### Task 3: Google-first client account dialog

**Files:** Modify `flutter/lib/common/widgets/login.dart`; create `flutter/lib/common/widgets/gadesk_account_panel.dart`, `flutter/test/gadesk_account_panel_test.dart`; modify user-model error mapping only if required by the new panel. Use existing translations or feature-specific translated text without editing `src/lang/template.rs`.

**Interfaces:** `GadeskAccountPanel({required bool loading, required String? errorMessage, required Widget? providerButton, required VoidCallback onRetry})` is a presentation-only widget. It consumes `LoginWidgetOP` with provider Google and the existing `_OidcAuthController`; it does not manage tokens or create another auth state machine. Enable only when `appName == 'GADESK'`.

- [ ] Write widget tests asserting Google signup explanation, no unusable username/password form, accessible retry during a readable failure, and responsive layout at mobile width. Run them and observe failure before implementation.
- [ ] Add the panel and a thin GADESK branch in the dialog. Preserve upstream dialog behavior for other app names. Show real configured Google availability; when not configured, show setup/unavailability rather than pretend login works. Reuse existing auth start/cancel/result parsing/logout and native browser opening. Remove token/body logging along the changed login path.
- [ ] Run focused Flutter tests and analyzer for changed files. Reproduce cancel/retry and close-during-login against the staged server; confirm an old response cannot complete the new attempt. Commit.

### Task 4: Owner setup, end-to-end verification and deployment

**Files:** GOOGLE.md, WSS.md, private VPS config and nginx extension; source patch remains tracked. Privacy draft under `deploy/gadesk/downloads/privacy.html` only after owner supplies responsible entity/contact and approves its factual content.

**Interfaces:** Owner supplies a web OAuth client in Google Cloud with the exact approved callback and external audience. Secret is entered through private server configuration, never pasted into chat. Provide the owner concrete console values/instructions after staging is ready; hand off credential creation and agreements.

- [ ] Prepare the exact OAuth setup checklist and factual privacy draft for owner review. Do not activate billing, publish invented contact/legal data or claim Google verification is complete.
- [ ] With owner-provided OAuth configuration, run two distinct Google accounts through first login, repeat login, cancellation, expiration and logout. Confirm identical Google account returns the same personal data across clients and separate accounts see separate data. Keep accounts ordinary `pro`; do not grant control/admin merely by registration.
- [ ] Back up production SQLite consistently and save nginx/image/config rollback artifacts privately. Deploy the patched image/config and allowlist with config tests and health checks; verify remote WSS registration and encrypted relay still work before accepting production deployment.
- [ ] Verify Google discovery/options and live client flow through HTTPS. If Google setup is pending, finish independently testable code/UI but keep this step explicitly pending; do not advertise public signup as operational.
- [ ] Commit verified operational documentation. Publish app packages together with the interface plan's release task to avoid rebuilding all three platforms twice.

## Self-review

All authentication and isolation requirements map to Tasks 1–4. Production Google access and privacy approval are external owner dependencies; they do not block patch, staged API tests or UI work. No unrelated signaling, account-protocol or shared-submodule change is planned.
