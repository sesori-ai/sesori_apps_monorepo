# Step 3 — Identity-Bound Desktop Bundles

Status: **3.a done**, merged in [PR #1492](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1492)
as `575dd34dc322f88289efb68731482efe8885fa4b`. Immediate successor
[3.b](step-03b.md) surfaces retained repair guidance in the window/tray before
installers. See the 13-PR mapping and ownership in [PLAN.md](../PLAN.md).

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

### Final accepted head

[Run 34987193233](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/34987193233)
passed all six native rows at its Actions merge checkout
`83e2e58b39732f706964f313ad13fa7d3f0f7f50`. Separately, the accepted PR revision was
`1528c16f8f6f3b224331757694ed0d5ddbd573cc`, with all 24 checks passing at acceptance.
Downloaded manifests/inventories identify that measured merge checkout and helper
`1.8.4`; the inventories report canonical tracked source cleanliness, and the
relocated-helper supervised E2E logs record passing tests.

| Target | Evidence artifact |
|---|---|
| macOS x64 | 10405065795 |
| macOS arm64 | 10404566144 |
| Windows x64 | 10404880077 |
| Windows arm64 | 10403864225 |
| Linux x64 | 10404022643 |
| Linux arm64 | 10404152364 |

Downloaded inventories and matrix summary are under
`build/desktop-bundle-evidence/native-ci-1528c16/`. The preceding run's Intel
framework-download timeout did not require a production code, SDK-pin or timeout
change. PR head, Actions merge checkout and eventual squash SHA are distinct.

Reproduce the download/assertion procedure from the **repository root** (also the
original retrieval cwd). These are the same `gh api` ZIP, manifest, inventory and
E2E-log checks used for the recorded evidence; they do not rebuild or launch a GUI.
GitHub access and unexpired artifacts are required; CI retains them for 14 days.

```bash
python3 - <<'PY'
import io, json, subprocess, zipfile
base = "repos/sesori-ai/sesori_apps_monorepo"
source = "83e2e58b39732f706964f313ad13fa7d3f0f7f50"
def api(endpoint):
    return subprocess.check_output(["gh", "api", "--allow-escape-sequences", base + endpoint])
artifacts = json.loads(api("/actions/runs/34987193233/artifacts"))["artifacts"]
verified = []
for artifact in artifacts:
    if not artifact["name"].startswith("desktop-qualification-"):
        continue
    with zipfile.ZipFile(io.BytesIO(api(f'/actions/artifacts/{artifact["id"]}/zip'))) as archive:
        names = archive.namelist()
        inventory = json.loads(archive.read(next(n for n in names if n.endswith("inventory.json"))))
        manifests = [json.loads(archive.read(n)) for n in names if n.endswith("desktop-bundle.json")]
        assert inventory["sourceSha"] == source
        assert inventory["relocatedHelperVersion"] == "1.8.4"
        assert not inventory["trackedSourceDirty"]
        assert manifests and all(m["sourceSha"] == source and m["version"] == "1.8.4" for m in manifests)
        assert b"All tests passed!" in archive.read(next(n for n in names if n.endswith("supervised-e2e.log")))
        verified.append(artifact["name"])
        print(artifact["name"], artifact["id"], source, "helper=1.8.4 clean-source E2E=passed")
assert len(verified) == 6
PY
```

## Review and remaining gates

Architecture implementation review of `350cb8e` from `ed9b15ba`, run
`05d41c7d-dd8d-4372-80a0-3028c92ba058`, approved with no findings. It confirmed model,
producer, resolver and lifecycle ownership. The separate 3.b presentation plan was
approved with no findings in run `5df8ad69-ea18-4776-8ddc-2335bdc28609`; its
implementation is tracked separately in [step-03b.md](step-03b.md), not folded into 3.a.

SDK pairing and version diagnostics at `4e32d887111ec87ab0d3d3481b5edd235553f5f9`
passed eight cases via the same version-test command above, `dart analyze --fatal-infos
tool/sync_versions.dart` from root, and `flutter analyze --no-pub --fatal-infos` from
`client/desktop`. The final native run above includes those corrections.
No actual GUI/account flow, minimum-OS execution, signed installer, real upgrade, or public release
is claimed. No signing credentials, application data or publication infrastructure
were used. Parent and platform release gates remain open.
