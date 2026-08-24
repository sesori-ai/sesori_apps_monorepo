# Step 43 — Installer Parity, Codegen Freshness, And Bridge Linting

## Re-verified evidence

- `install.sh` already honored `GITHUB`/`GITHUB_API` overrides and accepted only
  exact three-component stable tags, while `install.ps1` hardcoded GitHub hosts
  and `[version]::TryParse` also accepted four-component versions.
- OpenCode SSE output is fully reproducible from its committed event manifest;
  the OpenAPI client still depends on an uncommitted upstream specification and
  remains outside the offline freshness check.
- Analyzer plugins must be declared at the pub-workspace root. Packages that
  include `bridge/analysis_options.yaml` receive `no_slop_linter`; packages that
  continue including `bridge/app/analysis_options.yaml` do not.

## Change

- Aligned `install.ps1` release selection and host overrides with `install.sh`,
  and added a non-installing library mode so the real PowerShell resolvers can
  run against shared release fixtures.
- Added fixture coverage for incomplete releases, prereleases, invalid tag
  prefixes, four-component versions, release ordering, and overridden archive,
  checksum, and API URLs.
- Added a Bridge CI freshness job that regenerates committed OpenCode SSE output
  offline and fails on a diff. Bridge analysis now resolves the analyzer
  plugin's own dependencies before loading it.
- Enabled `no_slop_linter` in `sesori_bridge_foundation`,
  `sesori_plugin_interface`, and `sesori_plugin_runtime`; fixed their 15, 37,
  and 41 findings respectively. Intentional public, callback, JSON, and opaque
  error boundaries use narrow documented suppressions.
- Made managed-process start-abort signals required and non-null across the
  internal runtime contract, and let debug logging retain an original error and
  stack trace without escalating expected probe misses to warnings.
- Recorded the deferred larger-package counts in `TRACKER.md` and updated the
  positive installer regression contract.

## Verification

- `dart test test/tool/installers_test.dart`: passed, 28 tests; 2 executable
  PowerShell cases skipped because PowerShell is not installed locally.
- `bash -n install.sh`: passed.
- `dart run tool/generate_sse_events.dart`: reproduced 44 variants and 6 refs;
  the generated-file diff check passed.
- Full package suites passed for `sesori_plugin_interface` (152),
  `sesori_bridge_foundation`, and `sesori_plugin_runtime` (123).
- `make analyze`: passed all 12 bridge packages with `--fatal-infos`; the three
  opted-in packages reported no `no_slop_linter` findings.
- `git diff --check`: passed.
- Architecture implementation review approved the complete Step 43 diff with
  no findings; independent correctness review also found no issues.
- The pinned formatter formatted the files it could parse but still crashes on
  existing enhanced enums with `Null check operator used on a null value`;
  analyzer and diff checks remain the formatting authority for those files.
