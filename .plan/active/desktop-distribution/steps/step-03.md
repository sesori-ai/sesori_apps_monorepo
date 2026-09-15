# Step 3 — Identity-Bound Desktop Bundles

Status: **3.a in review** in [PR #1492](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1492).
Immediate successor **3.b** surfaces retained repair guidance in the window/tray
before installers. See the 13-PR mapping and ownership in [PLAN.md](../PLAN.md).

## Foundations

Desktop-core owns immutable generated `DesktopBundleIdentity`. The build-time
producer stages complete GUI/helper/native assets from committed source with locked
dependencies. Release resolution uses only the installed executable and validates
identity on every spawn; debug/profile retains development overrides. Version sync
preserves independent build suffixes. No database, wire or lifecycle-owner change.
Step 3.a refuses invalid bundles with local diagnostics; user-facing failure state
belongs to 3.b, not an already-complete UI claim.

## Reproducible local checks

The initial implementation tree committed as `1d9f8ce` passed these explicit scopes
(using the pinned Flutter 3.47.4 / Dart 3.13.3 toolchain):

| Cwd | Command | Cases |
|---|---|---|
| `client/module_desktop_core` | `dart test test/foundation/desktop_bundle_identity_test.dart --reporter expanded` | 3 |
| `client/desktop` | `flutter test test/core/platform/desktop_bridge_executable_path_resolver_test.dart test/core/platform/desktop_packaged_bridge_path_test.dart test/tool/stage_desktop_bundle_test.dart --reporter expanded` | 30 |
| `bridge/app` | `dart test test/tool/sync_versions_test.dart --reporter expanded` | 7 |
| Repository root | `python3 -m unittest discover -s .github/scripts -p test_qualify_desktop.py` | 11 |

Raw logs are under ignored `build/desktop-bundle-evidence/test-*.log`. Core/desktop
analysis, root version-tool analysis and actionlint also passed. Generated files
were regenerated, not edited. The later `7ff3293` content-guard correction adds two
Git fixture cases (six staging tests total): unchanged LF regeneration after CRLF
checkout passes, while tracked, staged, deleted and untracked source edits fail.
The first fixture failed against the prior status-based guard, then passed.

After merging incoming main as `350cb8e8c9cb18187ab8ed4cca6af5fc430e0a3c`, local
macOS ARM64 staging built seven native binaries including three helper binaries.
Compiler identity equaled the helper manifest and native version/build `1.8.4`/`1`;
source diff was empty and the relocated helper passed its isolated supervised E2E.

## Native CI

[Run 34976451046](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/34976451046)
passed all six native staging/inventory/relocated-helper E2E rows at PR head
`7ff3293bc0071b6bb93a573cff9bcd60428a8a99`; all PR checks were 24/24 passing.
Every downloaded inventory/manifest identifies Actions merge checkout
`51315ce1cd16713f8ec4c5a2f2ea632258dc5797`, helper `1.8.4`, and no canonical tracked
source changes. Raw inventories: `build/desktop-bundle-evidence/native-ci-7ff3293/`.

Windows' initial failure was Git stat-only reporting after LF regeneration with
`core.autocrlf=true`, not changed source. Diagnostic artifact `10399290759` from
run `34975281444` records the empty patch and LF index/worktree. The real Git fixture
reproduces it; the guard now compares canonical content and separately rejects
untracked files. Failure-time diagnostics remain retained without resetting Git.

## Review and remaining gates

Architecture implementation review of `350cb8e` from `ed9b15ba`, run
`05d41c7d-dd8d-4372-80a0-3028c92ba058`, approved with no findings. It confirmed model,
producer, resolver and lifecycle ownership. The separate 3.b presentation plan was
approved with no findings in run `5df8ad69-ea18-4776-8ddc-2335bdc28609`; implementation
remains pending, not folded into 3.a.

SDK pairing and version diagnostics at `4e32d887111ec87ab0d3d3481b5edd235553f5f9`
passed eight cases via the same version-test command above, `dart analyze --fatal-infos
tool/sync_versions.dart` from root, and `flutter analyze --no-pub --fatal-infos` from
`client/desktop`. Current-head native CI is still required after those corrections.
No actual GUI/
account flow, minimum-OS execution, signed installer, real upgrade, or public release
is claimed. No signing credentials, application data or publication infrastructure
were used. Parent and platform release gates remain open.
