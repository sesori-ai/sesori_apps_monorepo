# Google Antigravity in Sesori

Sesori integrates Google's **official proprietary Antigravity ACP runtime**, not `agy -p` or a community adapter.
Read [Google's terms](https://antigravity.google/terms) and
[Antigravity documentation](https://antigravity.google/docs/)
before downloading or authenticating. Installing the runtime does not grant Google service access.

## Runtime and platform requirements

| Item | Supported contract |
|---|---|
| ACP registry package | `1.1.1` |
| Exact ACP runtime identity | `agy_acp_server_1.1.1` |
| Bridge hosts | macOS arm64; Linux x64/arm64; Windows x64/arm64 |
| Unsupported host | macOS x64, including an explicit binary path |
| Authentication | Personal Google OAuth (`oauth-personal`) only |

Business/Enterprise OAuth, Gemini API keys and Agent Platform authentication are not exposed by this integration.
The [pinned release facts](../bridge/sesori_plugin_antigravity/lib/src/foundation/antigravity_release.dart) contain the
five official archive URLs, checksums and file sizes. Registry package version and ACP runtime identity are different:
managed version directories use `1.1.1`, while validation checks the exact runtime identity above.
A pair reporting the earlier `agy_acp_server_20260818_01_RC01` identity no longer passes that exact check.
An explicit binary path remains authoritative, so replace its complete pair rather than expecting managed fallback.

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
2. Sesori opens the Google authorization page automatically; complete personal-account authorization in the browser.
3. Desktop connected to its exact local supervised bridge lets that bridge receive its own loopback callback. Remote
   desktop and mobile bind the exact issued callback on the client before opening the browser.
4. Mobile returns to Sesori through a session-scoped native callback containing only a random nonce. OAuth state and
   code remain in the captured loopback request. Remote desktop shows a static return-to-Sesori page.
5. Sesori forwards the captured callback once. The bridge validates its issued endpoint and state, then exchanges the
   code. Wait for bridge-confirmed authentication; browser return or callback delivery alone is not success.

There is no URL copy/paste or manual fallback. Do not post callback URLs to chat, issues, screenshots or logs. The
bridge accepts only the issued loopback endpoint and matching state for that attempt and never follows callback
redirects. An expired/cancelled attempt requires a fresh login. Use the authentication sheet's cancel action to stop an
attempt; merely dismissing the sheet does not cancel it.

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
- **Models:** one primary agent is exposed. Before the first chat, Sesori discovers the account catalog through one
  retained no-prompt native session under `GEMINI_HOME/antigravity-acp/conversations`. Reuse performs no ACP work;
  refresh resumes that same session, and restart recovers it through standard `session/list`. The artifact remains in
  Google's profile because the pinned runtime has no delete capability, but Sesori hides its cwd from list, project,
  import and metadata-recovery results. Exact paired `-high`/`-medium`/`-low` IDs and matching label suffixes become
  variants of one picker model; ambiguous or future shapes stay separate. Dispatch always sends the exact native ID,
  while live and replay metadata records the normalized model and variant. Failed refresh retains the last-good catalog.
- **History:** replay uses ACP load; live continuation prefers advertised resume. Both use the same normalized updates.
  Explicit import can recover bounded session/cwd metadata from the isolated profile's `.meta` files, once per cold
  live connection. Normal catalog reads use Sesori's database, not repeated provider scans; bridge/live attribution wins
  over recovered fallback metadata. Sesori never parses private Google SQLite/brain content.
- **Images and tools:** prompt and returned image content use the shared bounded attachment path. Provider-local image
  filenames are metadata only: Sesori does not open or fetch them. Model/account rejection remains visible. Tool
  output is bounded and normalized consistently for equivalent live/replay source envelopes; a nonzero exit note is not
  an ACP protocol failure.
- **Sub-agents:** Antigravity can delegate internally, but its official ACP projection exposes that work only as generic
  parent-local tool calls. It supplies no trustworthy child identity or lifecycle, and live versus replayed invocation
  status disagrees. Sesori therefore does not show Antigravity inline subtask tiles or child transcripts and cannot
  offer sub-agent-scoped stop. Normal turn-wide cancellation still applies.
- **Deletion:** the pinned runtime has no standard close/delete capability. Deleting in Sesori removes its own catalog
  and transcript data and retains a tombstone against re-import; it does not erase Google's conversation/profile files.
- **Presentation:** shared harness settings and chooser surfaces show **Antigravity** with Google's official full-colour
  mark in light and dark themes. Older clients without the bundled artwork use their generic plug fallback.

## Verification status and further contracts

Implementation is not a claim of completed cross-platform end-to-end verification. Official archive integrity was
checked for all five targets of package `1.1.1`. Native initialize-only and managed-pipeline correctness has been exercised
on macOS arm64 in disposable state. The earlier bounded authenticated ACP probe against package `1.0.0` verified only
the generic sub-agent projection described above; that observation was not rerun for `1.1.1`.
Native Linux/Windows installation, real personal OAuth, authenticated discovery-session creation/resume, full
ordinary session/image/history flows and the final cumulative L1–L5 matrix remain unverified. Missing test
infrastructure is a blocked result, not a pass.

The implementation plan was retired under the owner's
[explicitly accepted verification reduction](../.plan/completed/antigravity-harness/PLAN.md).
The recorded gaps remain unverified; retirement is not a full L5 sign-off.

- [Capability matrix and per-harness login support](HARNESS_CAPABILITIES.md)
- [Architecture and ownership](ARCHITECTURE.md#antigravity-boundaries)
- [Runtime activation and setup](regression/antigravity-descriptor-and-setup.md)
- [Personal authentication](regression/antigravity-personal-authentication.md)
- [Regression catalog](regression/README.md)
