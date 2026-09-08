# Google Antigravity in Sesori

Sesori integrates Google's **official proprietary Antigravity ACP runtime**, not `agy -p` or a community adapter.
Read [Google's terms](https://antigravity.google/terms) and
[Antigravity documentation](https://antigravity.google/docs/)
before downloading or authenticating. Installing the runtime does not grant Google service access.

## Runtime and platform requirements

| Item | Supported contract |
|---|---|
| ACP registry package | `1.0.0` |
| Exact ACP runtime identity | `agy_acp_server_20260818_01_RC01` |
| Bridge hosts | macOS arm64; Linux x64/arm64; Windows x64/arm64 |
| Unsupported host | macOS x64, including an explicit binary path |
| Authentication | Personal Google OAuth (`oauth-personal`) only |

Business/Enterprise OAuth, Gemini API keys and Agent Platform authentication are not exposed by this integration.
The [pinned release facts](../bridge/sesori_plugin_antigravity/lib/src/foundation/antigravity_release.dart) contain the
five official archive URLs, checksums and file sizes. Registry package version and ACP runtime identity are different:
managed version directories use `1.0.0`, while validation checks the exact runtime identity above.

## Install or supply the pair

### Managed installation

1. Start your bridge and connect a current Sesori mobile or desktop client.
2. Open harness settings, then **Antigravity**. The overview download icon opens detail; it does not start a download.
3. Review the setup guidance and Google links before choosing the explicit installation button.
4. Wait for completion, then authenticate when requested. Installation alone does not sign you in.

On Linux, install Info-ZIP `unzip` with ZipInfo support first; see the
[Linux prerequisite](../bridge/INSTALL.md#linux-antigravity-managed-runtime-prerequisite).
Sesori checks the extractor before downloading, but does not install system packages for you.

The bridge downloads directly from `dl.google.com`, checks the pinned archive digest, rejects unsafe archive paths and
symlinks, and on POSIX makes the server executable; the sibling harness retains its archived permission mode.
It then validates using an isolated **initialize-only** ACP process before placement.
Validation creates no session and initiates no OAuth. Disposable validation state is cleaned up before a
successful result. Archive listing and extraction each have a conservative two-minute command limit, not a guarantee
of total installation duration.

A first installation requires an explicit action. Existing Sesori-managed installations may upgrade on bridge start.
Pre-placement rejection or abort preserves retained supported prior packages; this is not arbitrary post-placement
rollback. There is no client pause/cancel-install command. See the
[managed installation contract](regression/plugin-runtime-installation.md) for shared failure and upgrade behavior.

### Manual installation

Use the official archive for the bridge host and keep both matching files together:

| Host | Server | Mandatory sibling |
|---|---|---|
| macOS arm64 / Linux x64 or arm64 | `agy_acp_server.par` | `localharness_external` |
| Windows x64 or arm64 | `agy_acp_server.exe` | `localharness_external.exe` |

On POSIX hosts, both files must be executable. Make the server discoverable on the bridge process's PATH or start with
`sesori-bridge --antigravity-bin <path-to-server>`. The explicit server path is authoritative: Sesori does not silently
fall back from it, and managed Install/upgrade is disabled while it is configured.
Without an override, resolution prefers a validated PATH pair, then an already-installed managed pair. The normal
Antigravity app or a separately authenticated Google CLI is not a substitute for this exact ACP pair/profile.

## Personal Google login, including a remote bridge

Sesori account login pairs your devices; Antigravity login is a separate Google authorization for the harness.

1. Start authentication from Antigravity's harness settings in a **current** mobile or desktop client.
2. Follow the Google authorization link offered by Sesori and complete personal-account authorization in the browser.
3. If the browser is on the bridge host, the loopback callback can complete directly.
4. If the browser is on another device, its final loopback page may fail to load because the listener is on the bridge.
   Copy the complete final return URL from that browser into Sesori's authentication sheet and submit it there.
5. Wait for Sesori's authenticated result. Opening the browser or delivering a callback is not itself success.

Paste the return URL only into the active Sesori challenge. It contains a short-lived credential: do not post it to
chat, issues, screenshots or logs. The bridge accepts only the issued loopback endpoint and matching state for that
attempt; it never follows callback redirects. An expired/cancelled attempt requires a new login.
Use the authentication sheet's cancel action to stop an attempt; merely dismissing the sheet does not cancel it.

There is no bridge-CLI login or automatic bridge-host browser fallback. An older client unable to show the browser
challenge must update; an already-authenticated profile can still be used without that login UI. A headless bridge
needs no browser of its own, but does need a current connected client for initial authentication.

## Profile, approvals and sessions

- **Isolation:** login and live execution share a plugin-owned `profile/antigravity-acp` beneath Antigravity's bridge
  state. It does not import ambient Google credentials or reuse your normal Google/Antigravity profile.
  Runtime processes receive a sanitized environment with parent inheritance disabled. Setup inspection checks only
  sibling files and isolated token-file presence; it does not read token contents, spawn a process or validate a login.
- **Supervision:** prompts use mode `default`, never `auto_edit` or `yolo`. Ordinary permissions offer only
  safe advertised once-kind choices. Persistent approvals and every warning-bearing choice are excluded independently.
  Supported single-choice questions retain the provider's options; malformed or ambiguous requests cancel, not guess.
- **Models:** one primary agent is exposed. Until a real new/load/resume response supplies a catalog in a fresh process,
  there is no model picker and the first new session uses the account default. Sesori does not create scratch sessions
  just to discover models. Later choices use exact advertised model IDs; stale choices reject before dispatch when the
  catalog is known. Reconnect clears the catalog and restores real session residency before strict selection checks.
- **History:** replay uses ACP load; live continuation prefers advertised resume. Both use the same normalized updates.
  Explicit import can recover bounded session/cwd metadata from the isolated profile's `.meta` files, once per cold
  live connection. Normal catalog reads use Sesori's database, not repeated provider scans; bridge/live attribution wins
  over recovered fallback metadata. Sesori never parses private Google SQLite/brain content.
- **Images and tools:** prompt and returned image content use the shared bounded attachment path. Provider-local image
  filenames are metadata only: Sesori does not open or fetch them. Model/account rejection remains visible. Tool
  output is bounded and normalized consistently for live/replay; a nonzero exit note is not an ACP protocol failure.
- **Deletion:** the pinned runtime has no standard close/delete capability. Deleting in Sesori removes its own catalog
  and transcript data and retains a tombstone against re-import; it does not erase Google's conversation/profile files.
- **Presentation:** settings and chooser surfaces use the descriptor name **Antigravity**. ID-only surfaces may show
  `antigravity` with the generic plug icon. That fallback is intentional, not a missing runtime or login indication.

## Verification status and further contracts

Implementation is not a claim of completed cross-platform end-to-end verification. Official archive integrity was
checked for all five targets. Native initialize-only and managed-pipeline correctness has been exercised on macOS arm64
in disposable state. Native Linux/Windows installation, real personal OAuth, full authenticated session/image/history
flows and the final cumulative L1–L5 matrix remain unverified.
Missing test infrastructure is a blocked result, not a pass.

The implementation plan was retired under the owner's
[explicitly accepted verification reduction](../.plan/completed/antigravity-harness/PLAN.md).
The recorded gaps remain unverified; retirement is not a full L5 sign-off.

- [Capability matrix and per-harness login support](HARNESS_CAPABILITIES.md)
- [Architecture and ownership](ARCHITECTURE.md#antigravity-boundaries)
- [Runtime activation and setup](regression/antigravity-descriptor-and-setup.md)
- [Personal authentication](regression/antigravity-personal-authentication.md)
- [Regression catalog](regression/README.md)
