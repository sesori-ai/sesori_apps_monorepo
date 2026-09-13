# Step 6 — OMP Windows ARM64 mapping

## Scope

Add `PlatformOs.windows` / `PlatformArch.arm64` to the existing plugin-owned
`OmpRuntimeManifest._assets` map. This is four production lines, with no new
class, API, lifecycle, installer, shared-runtime branch, client code or generated
output. The existing asset service resolves the entry directly; Linux keeps its
separate libc repository/probe. Target `18.1.19`, floor `17.2.13`, PATH/explicit
binary authority, direct executable layout and launch/approval policy are unchanged.

On a Windows ARM64 bridge, OMP can now advertise managed installation when no
explicit binary override suppresses it. The selected asset is the ARM64 executable,
not the Windows x64 asset. Actual native installation/ACP execution remains
unverified; implementation status is not a native pass. This follows the owner's
update-first policy without weakening production validators or probe isolation.

## Artifact provenance

The artifact was already independently downloaded as opaque bytes in Step 5:

- Release: [OMP v18.1.19](https://github.com/can1357/oh-my-pi/releases/tag/v18.1.19).
- Source commit: `e4dd2ec3b487f216c569281e2cdb7ec476a81f2e`.
- Asset: [`omp-windows-arm64.exe`](https://github.com/can1357/oh-my-pi/releases/download/v18.1.19/omp-windows-arm64.exe).
- Size: **150,732,800 bytes**.
- SHA-256: `4a5e90e1f1b85a263862b190860caaff76da6890863bbdbaaf29600a0eb54afb`.
- Independent hash matches both GitHub's release digest and `SHA256SUMS.txt`.

The new entry and all seven existing mappings were reconciled with the retained
machine-readable `step-5/metadata/omp-independent-integrity.json`. No download,
rehash, binary parsing or candidate execution was repeated. Other mappings and
digests are unchanged. Earlier OMP native observations remain attributed to
`18.1.18`, not `18.1.19` or Windows ARM64.

## Focused checks

Using pinned Dart 3.13.3 from Flutter 3.47.4-stable:

- `dart test --reporter=json test/omp_runtime_manifest_test.dart test/omp_runtime_asset_repository_test.dart`:
  **10 cases pass**, five per suite, no skipped/failed counted cases and
  `done.success: true`.
- Manifest tests cover all eight direct-binary names, distinct digest shape,
  Windows ARM64 install availability, exact digest and release URL, and unchanged
  floor/version parsing.
- The additional asset-service case supplies a Windows ARM64 target and proves
  the existing production service selects the ARM64 entry without invoking the
  Linux libc command. It is an in-process selection test, not native execution.
- `dart analyze --fatal-infos` for `bridge/sesori_plugin_omp`: passes.
- Dart formatting: three changed Dart files, zero changes.

Local command/JSON/analyzer evidence is retained under
`.dart_tool/runtime-refresh-validation/step-6/`. The unchanged descriptor suites
and prior native probes were not rerun. Full CI remains CI-owned.

## Documentation and remaining check

The capability matrix and installation/setup regression documents distinguish
implemented Windows ARM64 mapping from native verification. A stale Antigravity
package/server sentence in the touched installation document was also corrected
to the already-adopted exact `1.1.1` pair; no Antigravity runtime behavior changed.
Existing installation analytics remains authoritative; no new action/event or
instrumentation is introduced. No compatibility shim, migration or cleanup
machinery is needed.

Final follow-up still needs a native Windows ARM64 host: install through the
production path into isolated state, verify `omp/18.1.19`, initialize ACP through
its real launch seam, and record bounded teardown/owned-process cleanup. macOS,
x64 Windows, hashes and simulated platform tests do not substitute for this
check. Credentials and further configured lifecycle tests remain separately
scoped in [PLAN.md](PLAN.md) and [TRACKER.md](TRACKER.md).
