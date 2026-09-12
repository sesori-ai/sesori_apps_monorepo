# Step 2 — Mechanical target verification

Date: 2026-09-12. Base: plan merge `a644652e0c1a03232dc33184b522124703636988`
([PR #1453](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1453)).

## Disposition

Four independently gated candidates are applied in this branch. Two remain
unchanged and blocked; this is not completion of every target or the series.
All independent floors, platform mappings, layouts, and launch policies remain
unchanged. DeepSeek is excluded. No new production classes, generated files,
wire contracts, or Sesori database changes are introduced.

| Harness | Previous target → branch target | Floor | Result |
|---|---|---|---|
| OpenCode | `1.18.19` → `1.18.30` | `1.14.0` | Pass |
| Copilot | `1.0.80` → `1.0.83` | `1.0.78` | Pass |
| Pi | `0.84.4` → `0.85.1` | `0.84.1` | Pass |
| Claude Code | `2.1.237` → `2.1.269` | `2.1.221` | Pass |
| Codex | `0.153.4` unchanged; candidate `0.154.0` | `0.139.0` | Partial / pin blocked: probe teardown |
| OMP | `17.3.8` unchanged; candidate `18.1.18` | `17.2.13` | Blocked: configured lifecycle fixture |

## Release identity

Old/candidate tags were resolved and rechecked without observed movement.
All selected releases had `draft=false` and `prerelease=false`. Official npm
metadata agreed with the selected versions. Claude's lagging npm `stable` tag
is a channel distinction, not a GitHub prerelease flag.

| Harness | Official release | Candidate source commit |
|---|---|---|
| OpenCode | [v1.18.30](https://github.com/anomalyco/opencode/releases/tag/v1.18.30) | `3104c1428ec91f809e5ab86631300de41eb6952e` |
| Copilot | [v1.0.83](https://github.com/github/copilot-cli/releases/tag/v1.0.83) | `be82101e70f0253b57519bebb9cc9d0f6dfb2ed2` |
| Pi | [v0.85.1](https://github.com/earendil-works/pi/releases/tag/v0.85.1) | `d981de1229ef899957bbe968bc8dcda02a21f477` |
| Claude | [v2.1.269](https://github.com/anthropics/claude-code/releases/tag/v2.1.269) | `df52d04a4e65195c1621fe6222e0564bcccb1804` |

These are resolved release/source identities, not signed-release or
source-to-binary attestation claims. No separate adapter publication is needed
for these four targets. Published Claude Agent SDK `0.3.269` explicitly declares
CLI `2.1.269`; its launch/control source was checked, not installed as a bridge
dependency.

## Managed asset integrity

All 18 adopted archives were independently downloaded and SHA-256 hashed.
Each digest matches official GitHub metadata. Copilot's `SHA256SUMS.txt` and
Pi's `SHA256SUMS` also agree; their checksum files were independently hashed
and matched their published digests. OpenCode publishes no checksum-file asset.

| Asset | SHA-256 |
|---|---|
| `opencode-darwin-arm64.zip` | `a5e43d6887386efc7d68ce49ae28e3bbdfdee3dfd1d7169b612c3ce67e53b1e8` |
| `opencode-darwin-x64.zip` | `7453007e58ff122401438d95ccb24334874b5908dcaee77883f96c23395d5710` |
| `opencode-linux-arm64.tar.gz` | `4111a55c2a02c0fac314bd51e9a2330280e6d29d2b85b9554fff6d62612566ed` |
| `opencode-linux-x64.tar.gz` | `55007246858165496ff85ba1c2b648f7421e8e2013bf4189a680c9ff8e699d17` |
| `opencode-windows-arm64.zip` | `35d6ff7d80aff5ade71ac06fc32dd89357b5b0bac050fc6db41ecf0929cea560` |
| `opencode-windows-x64.zip` | `c8c0e0d05ac3dac544a0edfad8de9eb244bf46c6c7a131c38619d40fcf31bd1f` |
| `copilot-darwin-arm64.tar.gz` | `80a5ded6f1db484b4661af676ea914605ecfbcaf49f6b4bed81e6df16cbd56bd` |
| `copilot-darwin-x64.tar.gz` | `7e4f7236b0cd5ee474e6ab6d35ea67b8c33d5ec6483498e0fdd0218f458b2d53` |
| `copilot-linux-arm64.tar.gz` | `213b3a267042dbac3cd8ae22c82f5ea04ff3cabc008108c0f895055d46be4473` |
| `copilot-linux-x64.tar.gz` | `ffbe1c429664b8a05efed67ecdb467123e40fcaa3c6c14ef9a98ba74da4687b7` |
| `copilot-win32-arm64.zip` | `63f35c0ce1a5fdcc6f3e584890d689b1ede8f930933394aaf7b5e139b53d2cc1` |
| `copilot-win32-x64.zip` | `0e07221a275fdf7e61619c53566e3a421fd646d74d8e9ca491dbbff221f22945` |
| `pi-darwin-arm64.tar.gz` | `d5f70e3c0cf7398eac239fd0261ee074d98b7ba7f6b43fe3617f052ed5b79d06` |
| `pi-darwin-x64.tar.gz` | `adb918b845625f184d8bea408d55eacaf21aa87238793c0f5b4f3b9737bce62b` |
| `pi-linux-arm64.tar.gz` | `042d20ae885ee4f3b102815f3280b962c377b2e9fb44de4037908cc530eae4d4` |
| `pi-linux-x64.tar.gz` | `494e498f47d74d21f40b3386f6a5e921a3d49531a169cab55bbdaca0ea1fe25a` |
| `pi-windows-arm64.zip` | `b25e96fe64c9f41f75a924c0d36f395abb98d6c6fec0b78aaa0b86926f938bb4` |
| `pi-windows-x64.zip` | `002fa95b90d521245b9985d8f168caebc237ad56e7e30b319807dee1b2e17e1c` |

The parent reconciled the production manifests against machine-readable hash
records and official snapshots. A Copilot macOS ARM64 digest transcription
error in the narrative handoff was caught; a targeted byte rehash confirmed
the raw records and the correct digest above before pinning.

## Current-host runtime evidence

Scope: **L2 Routine target-only**, macOS ARM64, isolated credential-free state.
Archives were parsed/extracted and candidates launched inside restrictive macOS
sandboxes, not merely temporary HOME directories. Candidate environments were
allowlisted; user profiles, projects, credentials, SSH agent, and MCP config
were not exposed. Network was denied except loopback where required.

- **Managed installers:** production composition/extraction/validation with
  temporary candidate manifests and local verified-byte HTTP adapters asserting
  exact candidate URLs. Expected paths, full payloads, executable identity,
  digest sentinels, and staging cleanup passed. Pi's package tree remained intact.
- **OpenCode:** exact version, loopback `serve`, health, SSE, production typed
  project/session/status reads, and bounded group teardown passed. Its production
  read-only catalog reader left main database and WAL hashes unchanged; transient
  SQLite SHM reader bookkeeping changed without observed schema/data mutation.
- **Copilot:** exact branded version and production `--no-auto-update --acp`
  initialization passed, including ACP v1 and `copilot-login`. No login/provider
  turn ran; teardown left no candidate process.
- **Pi:** exact version and reference RPC launch returned correlated successful
  `get_state` with object data. Shutdown completed within two seconds. Provider
  turns, settlement, retry, and compaction behavior were not reverified.
- **Claude:** official current-host archive integrity, exact version, production
  launch flags, and correlated stream-json initialization passed. The matching
  SDK vector and isolated synthetic-session resume also initialized. No live
  provider/replay-order/partial-delta/permission-exchange claim is made. This
  direct CLI has no managed-asset pin or automatic installation change.

Other platforms are integrity-checked but **not natively tested**. No UI,
authenticated-provider, Windows ARM64 feature, or multi-select gate is claimed.
Historical protocol observations and older compatible PATH fixtures are retained.

## Post-pin package checks

Pinned Flutter `3.47.4-stable` / Dart `3.13.3`; bridge `pub get` passed.
Executed tests were counted from non-hidden JSON reporter completion events.

| Owning package | Focused test files | Passed tests | `analyze --fatal-infos` |
|---|---:|---:|---|
| `sesori_plugin_opencode` | 7: manifest/policy/descriptor/availability/catalog/API/plugin | 160 | Pass |
| `sesori_plugin_copilot` | 3: manifest/descriptor/plugin | 17 | Pass |
| `sesori_plugin_pi` | 9: manifest/descriptor/launch/RPC frames/client/events/plugin/process/catalog | 162 | Pass |
| `sesori_plugin_claude` | 1: descriptor | 10 | Pass |
| **Total** | **20** | **349** | **4 packages pass** |

Claude launch/stream/protocol baseline tests had also passed during its lane;
unchanged passing suites were not rerun as post-pin evidence. The changed
Claude target expectation was rerun in its descriptor suite. Formatting passed
for all nine changed Dart files, with no formatting changes. CI owns the full
repository matrix. No architecture review is needed for these mechanical pins.

## Remaining blockers

- **Codex:** all six package hashes, install, exact identity, and both production
  transport handshakes passed. The scratch WebSocket probe could not reliably
  signal its owned process group inside the sandbox. Original and one directed
  cleanup-only follow-up timed out; bounded manual cleanup verified no candidate
  remained. A denied `kill -0` was not accepted as proof of absence. This is a
  probe-infrastructure blocker, not a demonstrated Codex regression. Target stays
  `0.153.4`; no more retries or accepted gate exception are implied.
- **OMP:** seven existing-platform executable hashes, production install,
  `omp/18.1.18`, and credential-free ACP v1 initialization passed. Required
  `authenticate(agent)`, persisted list/new/load, and cleanup need an explicitly
  authorized disposable configured provider/model fixture and bounded network
  scope. None was available; target stays `17.3.8`. Windows ARM64 was not added
  or natively qualified, and no multi-select behavior changed.

The plan remains active. Neither blocker is waived by publishing the four
passing targets. Further target/feature gates and the final matrix still apply.
Local raw metadata, probes, and logs are retained under
`.dart_tool/runtime-refresh-validation/`; they are not production code or
committed credential/profile data.
