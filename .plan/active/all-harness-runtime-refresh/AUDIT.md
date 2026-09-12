# Runtime Refresh Audit Record

This is the pre-implementation source-audit snapshot published in Step 1.
Its pending-gate statements describe that snapshot, not later execution.
[Step 2 verification](STEP-2-VERIFICATION.md) records subsequent downloaded-byte,
installer, runtime, and package-check evidence; [TRACKER.md](TRACKER.md) owns
current branch targets and outstanding blockers.

## Scope and evidence status

- Baseline: branch `update-target-runtime-all-harnesses` at
  `8879ea1a62cc52104509c4483fe611c7eb0287bf`.
- Registry count is 11; ten rows are in scope. DeepSeek is registered but
  explicitly excluded and unchanged; no DeepSeek candidate, producer, or
  opportunity audit is made here.
- Evidence was recovered from four supplied read-only reports: `rpc-rest`
  (OpenCode, Codex, Pi), `open-acp` (OMP, Hermes), `closed-acp` (Antigravity,
  Cursor, Copilot, Claude), and `owned-xai` (Grok), plus release-facts notes.
- This continuation did not repeat audit/network discovery, download bytes,
  install or execute a candidate, use credentials, or run project tests.
  Candidate values and digests below remain provisional implementation input.

## Source completeness ledger

| Lane | Covered and usable | Missing before target change |
|---|---|---|
| `rpc-rest` | Local seams/tests, release notes, captured source ranges, release metadata, six-asset metadata/checksum evidence, final old/new tag recheck | Independent bytes/hashes, managed install, loopback probes; source review was focused, not exhaustive |
| `open-acp` | OMP/Hermes local seams, ACP sources/tests, packaging facts, strong Hermes cleanup finding, final old/new tag recheck | All downloads/probes; partial bare-store object `ddc240592f0a5323e5e0dc8c8a7e8ed3b0ef4a62` stayed missing |
| `closed-acp` | Current seams/tests, stable refs, candidate metadata and packaging limits | Antigravity/Cursor final rechecks plus candidate bytes/layout/behavior; Copilot/Claude black-box behavior |
| `owned-xai` | Current adapter seam, stable-channel observation, namespace analysis | Grok final channel recheck and execution; source-to-binary association is unavailable but is not a routine gate |

Source silence is not proof of absence. Broad comparison statistics and focused
files are retained as evidence limits rather than exhaustive upstream review.

## Official release recheck snapshot

- Rechecked at **2026-09-12T12:50:56Z**. Official HTTP checks for seven old/new
  tagged pairs (OpenCode, Codex, Copilot, Claude Code, Hermes Agent, Pi, and OMP)
  were **28/28 successful**; stable flags were `false/false`
  (`prerelease=false`, `draft=false`) for every old and candidate release.
- Codex `rust-v0.154.0` remains an annotated tag object
  `36eab01061df3cde5f95ec20a526777b430091ba`, peeled to commit
  `6b9826e3aa83b1a5947db50f4332cb9c65f1b340`; record these as separate objects,
  never as one commit identity.
- Pi `v0.85.1` candidate commit is
  `d981de1229ef899957bbe968bc8dcda02a21f477`.
- Antigravity, Cursor, and Grok final rechecks remain pending.

## Ten-harness release ledger

Authorities are local production files. Candidate release links are public
references and require a final recheck immediately before implementation.

| Harness | Local authority | Current identity | Candidate identity/source | Distribution and disposition |
|---|---|---|---|---|
| OpenCode | `bridge/sesori_plugin_opencode/lib/src/runtime/open_code_runtime_manifest.dart` | `v1.18.19`; tag `2b72179c663cadcb54f54d9f19221b3fb3d11fb6` | [`v1.18.30`](https://github.com/anomalyco/opencode/releases/tag/v1.18.30), tag `3104c1428ec91f809e5ab86631300de41eb6952e` | Six ZIP/tar.gz single-binary assets; recommended after gates |
| Antigravity | `bridge/sesori_plugin_antigravity/lib/src/foundation/antigravity_release.dart`; runtime manifest | Registry `v2026.09.03-536e378`, commit `536e378b70a7a6d5f078a9160180e3569a23253c`; package `1.0.0`; ACP 1; server `agy_acp_server_20260818_01_RC01` | Registry [`v2026.09.12-d30bc9a`](https://github.com/agentclientprotocol/registry/releases/tag/v2026.09.12-d30bc9a), commit `d30bc9a7c011b522e8502281d5fbcfca51abd5ff`; agent update `81bf71b55e15f630c4fb8a86d20d3088071d2071`; package `1.1.1`; server pending | Five ZIP package directories; exact-pair probe first |
| Codex | `bridge/sesori_plugin_codex/lib/src/runtime/codex_runtime_manifest.dart` | `rust-v0.153.4`; tag object `042fb41b7c813ac7999105e886b2b7aa715b5081`, peeled commit `3d2ee51ca2d5db578f328aa75e20aa22c0197c9a` | [`rust-v0.154.0`](https://github.com/openai/codex/releases/tag/rust-v0.154.0); tag object `36eab01061df3cde5f95ec20a526777b430091ba`, peeled commit `6b9826e3aa83b1a5947db50f4332cb9c65f1b340` | Six canonical package tar.gz assets; recommended after both transports |
| GitHub Copilot | `bridge/sesori_plugin_copilot/lib/src/runtime/copilot_runtime_manifest.dart` | `v1.0.80`; tag `ef627e1baad937d3c8da45f8a5541c6fc3c97b6a` | [`v1.0.83`](https://github.com/github/copilot-cli/releases/tag/v1.0.83); tag `be82101e70f0253b57519bebb9cc9d0f6dfb2ed2` | Six single-binary assets; recommended after install/ACP |
| Cursor | `bridge/sesori_plugin_cursor/lib/src/runtime/cursor_runtime_manifest.dart` | Exact `2026.08.11-e8db854`; date floor `2026.07.16` | [official installer](https://cursor.com/install), exact `2026.09.10-fd3934a`; no immutable tag captured | Four package tar.gz assets; content/hash/install probe first |
| Claude Code | `bridge/sesori_plugin_claude/lib/src/runtime/claude_plugin_descriptor.dart` | `v2.1.237`; tag `770933ea1ad2fa7b858191e397a65e6644771c64` | [`v2.1.269`](https://github.com/anthropics/claude-code/releases/tag/v2.1.269); tag `df52d04a4e65195c1621fe6222e0564bcccb1804`; npm `latest` agrees | Direct CLI, zero managed assets; recommended after stream gate |
| Hermes Agent | `bridge/sesori_plugin_hermes/lib/src/runtime/hermes_plugin_descriptor.dart` | CLI `0.20.4`; tag `v2026.8.18`, commit `e624e9fde561e1add9388384012b295fde669ade` | [`v2026.9.11`](https://github.com/NousResearch/hermes-agent/releases/tag/v2026.9.11), CLI `0.21.2`, commit `939e45c91d751fadd94dcd1b873ac3cb44846213` | Direct `hermes acp`, zero managed assets; cleanup blocker |
| Pi | `bridge/sesori_plugin_pi/lib/src/runtime/pi_runtime_manifest.dart` | `v0.84.4`; tag `b79e4cc834970cca69daebffab7df1da7d1e52c4` | [`v0.85.1`](https://github.com/earendil-works/pi/releases/tag/v0.85.1); candidate commit `d981de1229ef899957bbe968bc8dcda02a21f477`; npm comparison `@earendil-works/pi-coding-agent` | Six package archives; recommended after RPC/compaction |
| Oh My Pi | `bridge/sesori_plugin_omp/lib/src/runtime/omp_runtime_manifest.dart` | `v17.3.8`; tag `858f7dd91fff9b84cf8a2c6a6bb85aa0e6d03a55` | [`v18.1.18`](https://github.com/can1357/oh-my-pi/releases/tag/v18.1.18), published 2026-09-11; tag `00085d4e7dfdcfbf302c122fa2682b410a0f43d1` | Seven current Sesori-manifest direct assets, official candidate eighth Windows ARM64 asset; approved separate mapping step |
| Grok Build | `bridge/sesori_plugin_grok/lib/src/runtime/grok_plugin_descriptor.dart` | `1.0.5` | [xAI stable](https://x.ai/cli/stable), channel `1.0.30`; captured source reports crate `1.0.24` | Direct CLI, zero managed assets; recommended after channel/ACP |
| DeepSeek (excluded) | `bridge/sesori_plugin_deepseek/lib/src/runtime/deepseek_runtime_manifest.dart` | `0.1.5` / `0.1.5` | None assessed | Existing six assets and all evidence remain untouched |

## Candidate managed-asset evidence

These 33 rows are publisher metadata or checksum-list values recovered from the
reports, not independent download hashes. Do not copy them into a manifest until
opaque-byte verification passes.

### OpenCode `v1.18.30`

| Asset | Recovered SHA-256 |
|---|---|
| `opencode-darwin-arm64.zip` | `a5e43d6887386efc7d68ce49ae28e3bbdfdee3dfd1d7169b612c3ce67e53b1e8` |
| `opencode-darwin-x64.zip` | `7453007e58ff122401438d95ccb24334874b5908dcaee77883f96c23395d5710` |
| `opencode-linux-arm64.tar.gz` | `4111a55c2a02c0fac314bd51e9a2330280e6d29d2b85b9554fff6d62612566ed` |
| `opencode-linux-x64.tar.gz` | `55007246858165496ff85ba1c2b648f7421e8e2013bf4189a680c9ff8e699d17` |
| `opencode-windows-arm64.zip` | `35d6ff7d80aff5ade71ac06fc32dd89357b5b0bac050fc6db41ecf0929cea560` |
| `opencode-windows-x64.zip` | `c8c0e0d05ac3dac544a0edfad8de9eb244bf46c6c7a131c38619d40fcf31bd1f` |

### Codex `rust-v0.154.0`

| Asset | Recovered SHA-256 |
|---|---|
| `codex-package-aarch64-apple-darwin.tar.gz` | `427ca74c027049e0cd1a330d611e7f8d1fe0f1eb6a6d85ac16f61bcf2cb4a485` |
| `codex-package-x86_64-apple-darwin.tar.gz` | `8052c6accbe0361bfbd424a10aa5f2226636ed8afb6dcbd5e6437993e57b16d8` |
| `codex-package-aarch64-unknown-linux-musl.tar.gz` | `97d93e11df72d3c26772db019e6ea8bb72c246500d46b98c760839f3240355e6` |
| `codex-package-x86_64-unknown-linux-musl.tar.gz` | `fc6e3e3b85f2cf7d664520ee5c66a7fe4aa12bae7d46834f47e2f165fd0d6f78` |
| `codex-package-aarch64-pc-windows-msvc.tar.gz` | `fcd888733e50e40acaf4278bedfbf4245cb2b934c99c6e5b263da850fd9f90c2` |
| `codex-package-x86_64-pc-windows-msvc.tar.gz` | `94cc5b3632769504c809f6c0364b693c0dfddc5c30c8361095d2263a07ac45a4` |

### Pi `v0.85.1`

| Asset | Recovered SHA-256 |
|---|---|
| `pi-darwin-arm64.tar.gz` | `d5f70e3c0cf7398eac239fd0261ee074d98b7ba7f6b43fe3617f052ed5b79d06` |
| `pi-darwin-x64.tar.gz` | `adb918b845625f184d8bea408d55eacaf21aa87238793c0f5b4f3b9737bce62b` |
| `pi-linux-arm64.tar.gz` | `042d20ae885ee4f3b102815f3280b962c377b2e9fb44de4037908cc530eae4d4` |
| `pi-linux-x64.tar.gz` | `494e498f47d74d21f40b3386f6a5e921a3d49531a169cab55bbdaca0ea1fe25a` |
| `pi-windows-arm64.zip` | `b25e96fe64c9f41f75a924c0d36f395abb98d6c6fec0b78aaa0b86926f938bb4` |
| `pi-windows-x64.zip` | `002fa95b90d521245b9985d8f168caebc237ad56e7e30b319807dee1b2e17e1c` |

### OMP `v18.1.18` checksum-list evidence

| Asset | Recovered SHA-256 |
|---|---|
| `omp-darwin-arm64` | `035a35dcb249edb939fa02b74fc7c0df9b2eb659079349fbffb188e1b558957a` |
| `omp-darwin-x64` | `29fead1b667dc969b825c5aa4798aadb5b7ec9b2f15c3304b10196d7afa4171d` |
| `omp-linux-arm64` | `1ae8273c231ceb88cebc9971901cf7f5d97ed4149cdc740a814f629cd2b4dcb2` |
| `omp-linux-x64` | `45421f9a5f112bc47cb9f77c4b4d7927631f8ff859624f821287ec854eb239fc` |
| `omp-linux-musl-arm64` | `24b80ad97661d3f76fbffa3f63121a33d744f87ba8c1ae40aa2c885152d5b677` |
| `omp-linux-musl-x64` | `23e2b7170a47f83cd2941e5f6fe51b2218873b8fe0de97a0d2170afa3cdba406` |
| `omp-windows-arm64.exe` | `4d8b68eb93f0e7dccfa6e8a400e42aa7e48b56c98f9debd324dc230452985af5` |
| `omp-windows-x64.exe` | `d9cf773ee3fd3823af9bc073c880fce4013920b2478bd5a02feff35920424378` |
| `SHA256SUMS.txt` | `67d8bbad739e622f93a5d362e99c3ce870ea425849cdd457108ae8d2a37c8a93` |

### Copilot `v1.0.83`

| Asset | Recovered SHA-256 |
|---|---|
| `copilot-darwin-arm64.tar.gz` | `80a5ded6f1db484b4661af676ea914605ecfbcaf49f6b4bed81e6df16cbd56bd` |
| `copilot-darwin-x64.tar.gz` | `7e4f7236b0cd5ee474e6ab6d35ea67b8c33d5ec6483498e0fdd0218f458b2d53` |
| `copilot-linux-arm64.tar.gz` | `213b3a267042dbac3cd8ae22c82f5ea04ff3cabc008108c0f895055d46be4473` |
| `copilot-linux-x64.tar.gz` | `ffbe1c429664b8a05efed67ecdb467123e40fcaa3c6c14ef9a98ba74da4687b7` |
| `copilot-win32-arm64.zip` | `63f35c0ce1a5fdcc6f3e584890d689b1ede8f930933394aaf7b5e139b53d2cc1` |
| `copilot-win32-x64.zip` | `0e07221a275fdf7e61619c53566e3a421fd646d74d8e9ca491dbbff221f22945` |

## Findings and corrections

- **OpenCode/Codex/Pi:** candidate source notes do not establish a new
  production seam. OpenCode DB-first import, Codex WebSocket plus stdio
  transports, and Pi RPC settlement remain required. Pi's prior npm 404 was
  queried against the wrong name; use `@earendil-works/pi-coding-agent`.
- **Codex identity:** recovered values distinguish tag object from peeled
  commit. The object IDs are not movement evidence; type and ref resolution
  must be verified again before pinning.
- **Antigravity/Copilot/Claude:** Antigravity package `1.1.1` still needs exact
  server identity and five archive bytes. Copilot `1.0.83` is stable; `1.0.84-5`
  remains held. Claude CLI `latest=2.1.269` versus npm stable dist-tag `2.1.236`
  is a channel distinction, not prerelease evidence; SDK `0.3.269` is separate.
- **Cursor:** official installer build `2026.09.10-fd3934a` needs complete URL,
  bytes, four local hashes, package layout, ACP checks, and a configured
  load/replay fixture. The configured fixture is pin-blocking; missing evidence
  blocks the Cursor pin. Self-hashing the official content is accepted pin
  evidence; no publisher checksum, signature, immutable release, or
  source-binary attestation gate is required.
- **Hermes:** candidate `0.21.2` omits empty `session/new` persistence while
  current cleanup unconditionally deletes the scratch ID and treats not-found
  as an error. The narrow cleanup change remains a target prerequisite, and a
  configured fixture for new/load is also required; missing fixture evidence
  blocks the Hermes pin. Preserve real DB failures and avoid broad cleanup
  machinery.
- **OMP:** official `18.1.18` has eight direct executables while the current
  Sesori manifest has seven; `omp-windows-arm64.exe` is an approved separate
  mapping. The OMP pin requires configured `authenticate(agent)`, list/new/load,
  and persisted-cleanup probes; missing fixture evidence blocks the pin. The
  Windows ARM64 feature additionally requires native Windows ARM64
  install/version/ACP smoke before its platform claim; current macOS arm64
  remains sufficient for ordinary old-platform target bumps, but a missing Windows
  runner blocks this feature, never implicitly accepting it. ACP busy/cancel
  settlement,
  forms, plan, location, and packaging notes are not blanket feature adoption.
- **Grok:** stable channel reports `1.0.30`; captured source still reports
  `1.0.24`, so source-to-binary association is incomplete but not a routine
  target gate. Source/SDK spelling `x.ai/...` normalizes to `_x.ai/...` on the
  wire; namespace drift is removed as a blocker. Versioned normalization
  evidence is [ACP 0.10.4 source](https://docs.rs/agent-client-protocol/0.10.4/src/agent_client_protocol/lib.rs.html#221-234).
  Exact direct launch and ACP probes remain required, including authenticated
  new/prompt/replay/model-selection/close; unavailable required fixture
  evidence blocks the Grok pin. Optional broad provider/model/child exploration
  remains non-gating, and source-to-binary association stays optional evidence.
- **ACP multi-select:** OMP's approved form path needs generic mapper support
  for array `items.anyOf`. Preserve one question per schema property: OMP's
  `qN` checkbox selections and `qN__other` custom text remain separate questions
  in the same form, using existing answers/UI. This retains provenance even
  when custom text equals an option label, without wire additions or OMP naming
  assumptions in the generic mapper. Its independent feature matrix is minimum
  sufficient **L2 Routine** scoped to this OMP ACP path, not unrelated L3
  catalog coverage. Require existing-widget automation plus an authoritative
  live OMP `askDialog`/ACP array roundtrip on at least one supported client,
  using the existing native fixture or an explicitly authorized isolated
  configured fixture, never ambient credentials. Exercise two choices plus
  a separate custom answer, selected values (including an identical option
  label/custom value), optional-custom omission, required omission/cancel,
  and unchanged single-choice behavior; missing live fixture/roundtrip blocks
  this feature gate. Other ACP plugins stay form-disabled. Its question
  regression/capability docs land in Step 7, not a later documentation PR.
- **Analytics and implementation shape:** reuse existing authoritative
  question-answer instrumentation; add no new event. Approved work adds zero new persistent or in-memory coordination parts, and no generated churn is expected. Estimates are approximately 200-450 authored lines for multi-select
  and 40-100 for OMP Windows ARM64 mapping; refine against local implementation
  without widening scope.
- Optional upstream features, floors, auth changes beyond named required probes,
  sub-agent claims, and considerable refactors remain declined or out of scope.
  No safe code removal was found.

## Pin-blocking configured/authenticated probes

| Harness | Required configured/authenticated probe | Missing fixture result |
|---|---|---|
| Cursor | Configured load/replay | Blocks Cursor pin |
| OMP | Configured `authenticate(agent)`, list/new/load, persisted cleanup | Blocks OMP pin |
| Hermes | configured new/load fixture | Blocks Hermes pin |
| Grok | Reference-required authenticated new/prompt/replay/model-selection/close | Blocks Grok pin |

Optional broad provider/model/catalog/child exploration is non-gating and does
not waive any missing required fixture.

## Feature-gate matrix

These gates are independent of target-only L2 evidence and use the minimum
sufficient scoped boundary from the regression README.

| Feature | Scope/boundary | Required evidence | Status |
|---|---|---|---|
| OMP Windows ARM64 | L2 Routine platform-specific gate before platform claim/retirement | Native Windows ARM64 install/version/ACP smoke; missing Windows runner blocks feature, never implicit acceptance | Blocked |
| OMP ACP multi-select | L2 Routine scoped only to OMP ACP form questions, not unrelated L3 catalog coverage | Existing-widget automation plus authoritative live OMP `askDialog`/ACP array roundtrip on at least one supported client: two choices+custom, selected values, required omission/cancel, single-choice unchanged | Blocked |

The configured/authenticated probes listed above are pin gates for their named
harnesses. Optional broad provider/model/catalog/child exploration remains
non-gating and does not waive missing required evidence.

## Integrity and probe gaps

No candidate bytes were independently hashed, installed, launched, or probed in
this run. The 33 digest rows above are metadata evidence only. Antigravity and
Cursor candidate content remains incomplete; direct CLIs have no managed asset
hash gate. Required future work uses the production installer/extractor under
sandboxed macOS arm64 managed state, disposable HOME/profile/config/cache roots,
loopback-only networking, filtered environment, bounded process-group cleanup,
and no ambient credentials. Native OMP Windows ARM64 execution remains a
**Blocked** feature until its required runner smoke; every other non-macOS path
remains **Untested**.

Account-backed provider, model, authentication, configured-session, child,
replay, or rich cancellation probes require explicitly authorized fixtures.
None was available here; no ambient credential was used. Pin-blocking required
fixtures are Cursor configured load/replay; OMP configured
`authenticate(agent)`, list/new/load, persisted cleanup; Hermes configured
new/load; and Grok authenticated new/prompt/replay/model-selection/close.
Missing required fixtures block respective pins with no implied waiver. The OMP
live `askDialog`/ACP array roundtrip is a separate multi-select feature gate;
optional broad provider/model/catalog/child exploration remains Blocked but
non-gating. A no-credential runtime pin does not claim unrequired provider
turns, auth, child lifecycle, or rich model behavior.

After approved pins, run each owning package's focused tests and
`dart analyze --fatal-infos`; regenerate only from source if a model/source
change ever requires it. No generated output is part of this planning slice.
