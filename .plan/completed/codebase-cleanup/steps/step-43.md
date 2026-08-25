# Step 43 — Installer Parity, Codegen Freshness, And Bridge Linting

## Re-verified evidence

- `install.sh` accepted only exact three-component stable tags, while
  `install.ps1` used `[version]::TryParse`, which also accepted four-component
  versions. Review confirmed that both installers must pin canonical GitHub hosts
  so environment variables cannot redirect executable downloads.
- OpenCode SSE output is fully reproducible from its committed event manifest;
  the OpenAPI client still depends on an uncommitted upstream specification and
  remains outside the offline freshness check.
- Analyzer plugins must be declared at the pub-workspace root. Packages that
  include `bridge/analysis_options.yaml` receive `no_slop_linter`; packages that
  continue including `bridge/app/analysis_options.yaml` do not.

## Change

- Aligned `install.ps1` release selection with `install.sh`, pinned both scripts
  to canonical GitHub hosts, and added a non-installing library mode so the real
  PowerShell resolvers can run against shared release fixtures.
- Added fixture coverage for incomplete releases, prereleases, invalid tag
  prefixes, four-component versions, release ordering, canonical archive,
  checksum, and API URLs, and hostile host environment variables.
- Added a Bridge CI freshness job that regenerates committed OpenCode SSE output
  offline and fails on a diff. Bridge analysis now resolves the analyzer
  plugin's own dependencies before loading it.
- Enabled `no_slop_linter` in `sesori_bridge_foundation`,
  `sesori_plugin_interface`, and `sesori_plugin_runtime`; fixed their 15, 37,
  and 41 findings respectively. Intentional public, callback, JSON, and opaque
  error boundaries use narrow documented suppressions.
- Made managed-process start-abort signals required and non-null across the
  internal runtime contract. Debug logging remains message-only; a caught probe
  launch error uses warning logging to retain its original error and stack trace.
- Recorded the deferred larger-package counts below and updated the
  positive installer regression contract.

## `no_slop_linter` counts

Only the three approved small packages include the workspace-root plugin
configuration. Larger-package counts were measured by temporarily including
that configuration, then restoring their existing analyzer options.

| Package | Findings | Step 43 enforcement |
| --- | ---: | --- |
| `app` | 567 | Deferred |
| `sesori_bridge_foundation` | 15 before fixes, 0 after | Enabled |
| `sesori_plugin_interface` | 37 before fixes, 0 after | Enabled |
| `sesori_plugin_runtime` | 41 before fixes, 0 after | Enabled |
| `sesori_plugin_opencode` | 403 | Deferred |
| `sesori_plugin_codex` | 250 | Deferred |
| `sesori_plugin_acp` | 217 | Deferred |
| `sesori_plugin_cursor` | 42 | Deferred |
| `sesori_plugin_omp` | 27 | Deferred |
| `sesori_plugin_claude` | 161 | Deferred |
| `sesori_plugin_pi` | 163 | Deferred |
| `sesori_plugin_hermes` | 5 | Deferred |

## Verification

- `dart test test/tool/installers_test.dart`: passed, 28 tests; 2 executable
  PowerShell cases skipped because PowerShell is not installed locally.
- `bash -n install.sh`: passed.
- `dart run tool/generate_sse_events.dart`: reproduced 44 variants and 6 refs;
  the generated-file diff check passed.
- Full package suites passed for `sesori_plugin_interface` (152),
  `sesori_bridge_foundation`, and `sesori_plugin_runtime` (123).
- Focused app repository suites passed 73 tests after the plugin-session API
  moved to required named parameters.
- `make analyze`: passed all 12 bridge packages with `--fatal-infos`; the three
  opted-in packages reported no `no_slop_linter` findings.
- `git diff --check`: passed.
- Architecture implementation review approved the initial Step 43 diff with no
  findings. The follow-up review skill was unavailable after two attempts; an
  independent correctness and security review of the feedback diff found no
  issues.
- The pinned formatter formatted the files it could parse but still crashes on
  existing enhanced enums with `Null check operator used on a null value`;
  analyzer and diff checks remain the formatting authority for those files.
