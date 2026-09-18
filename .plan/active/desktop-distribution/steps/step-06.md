# Step 6 — Private release preparation and publication gate

Ordinal 8/14. Builds on merged step 5 (#1506). Public publication remains blocked;
this implementation prepares evidence without tags, releases, signing, website
writes, new credentials, or changes to CLI/mobile finalizers.

## Code-informed implementation boundary

- `.github/workflows/desktop-release.yml` is manual and read-only. It downloads
  both CPUs' private packages/evidence from one successful qualification run.
  Source SHA, run ID and channel are explicit inputs; this workflow is macOS-only.
  Checkout is
  the workflow's tooling revision; it is not mislabeled as the package source.
- `.github/scripts/prepare_desktop_release.py` checks the producer run, both bundle
  identities, compiled channel/identity defines, clean-source patch, accepted
  notarization receipts, archive inventory equality and downloaded payload hashes.
  It produces deterministic private metadata/checksums in a fresh output directory.
  Package source, preparation source and packaging run remain separate identities.
- `.github/workflows/desktop-qualification.yml` passes the selected channel to the
  existing staging tool and uploads its non-secret defines alongside evidence.
  Old runs without these defines must be rebuilt; no inferred channel fallback.
- `.github/scripts/test_prepare_desktop_release.py` uses synthetic local files to
  prove consistency/rejection rules, deterministic results and read-only workflow
  constraints. `release-workflow-ci.yml` runs these offline tests.

The validator trusts the selected repository's qualification evidence. Hash and
receipt checks are not independent verification of Apple signatures or authorization
for release. The workflow downloads but never executes packages or launches a GUI.
It uploads only prepared metadata and run provenance; original payload/evidence
artifacts stay in the producer run with their existing retention. No storage
service, persistent state, new application lifecycle owner or updater is introduced.
Transient Python values only; no architecture-bearing application code changes.

## Release isolation and blockers

Proposed tags use `desktop-vX.Y.Z` or `desktop-vX.Y.Z-internal.N`. Explicit bridge
selectors require a `v` prefix, so desktop tags do not qualify. Generic GitHub
Latest is repository-wide: eventual publication must use `--latest=false` for
both desktop channels. This step generates a proposed tag but never creates it.
It neither consumes mobile/CLI versions nor moves `internal-release-attempt`.

Do not claim step 6 shipped from preparation. The owner-approved signing migration
is complete: all five values live only in `macos-signing`, shared CLI and direct
desktop native proof passed on both CPUs after repository-copy removal, and the
migration plan retired in #1534. Remaining gates:

- Full native macOS manual upgrade/data-preservation gates and parent desktop-app
  prerequisites; existing private package probes do not establish these.
- Live `https://sesori.com/desktop/` and verified public download links. The URL was
  explicitly selected by the user before the page existed.
- Actual immutable publication and public retrieval/signature checks, then channel
  metadata last. No publication credentials or hosted resources are provisioned here.

No automatic updater layers remain to clean up. The private producer stays separate
from public release authority. Windows/Linux publication remains disabled.

## Post-migration continuation

Fresh stable package run `35206885114` passed both native package jobs at source
`7aecbd943671290eca53506949a9c38f2d8da4d0`: x64 job `105154787465` and arm64 job
`105154787487` both completed signing/notarization, helper E2E, installed GUI/platform
fixture probes and private artifact upload. Read-only preparation run `35359083211`
then validated those packages as proposed `desktop-v1.9.0`, build 62. Its tooling
source was `beb99dc35e18ecbe596753ba7353237a817acf87`; package source remained the exact
prior SHA. The four prepared package hashes are retained in that run's private
metadata; neither run published a tag, release, feed or website.

The next bounded continuation adds credential-free `macos-upgrade-probe` qualification.
It consumes retained successful 1.8.4 and stable 1.9.0 package runs, verifies producer
provenance, clean source, strict identity ordering, notarization, DMG hashes, Developer
ID identity, tickets and Gatekeeper, then exercises actual DMG installation, accessible
tray Quit, no relaunch/orphan and bounded desktop/shared-state plus valid
login-registration preservation on both native CPUs. This closes only the private
signed helper-Off replacement slice. Authenticated
helper-On/failed-stop, real account/Keychain/TCC, minimum OS, public download and parent
Gate C remain explicit blockers rather than inferred passes.

Initial branch run `35361626933` stopped on both CPUs before mounting or executing a
package: retained 1.8.4 source `efefcbcff7e7b75bdde271c1c670333987530212`
was a reviewed commit in squash-merged PR #1503 rather than a direct `main` ancestor.
The corrected trust rule accepts either direct tooling ancestry or GitHub's association
with a merged-to-main PR whose merge commit is an ancestor, and records which path
accepted each source. It does not weaken producer, hash, identity, notarization or
native package checks.

Second branch run `35362043592` passed the corrected source gate and all DMG trust
checks, then stopped before copying either prior app into Applications. Both retained
packages intentionally contain a universal Flutter GUI (`x64` + `arm64`) and a
package-native bridge helper; the probe had incorrectly required the GUI itself to be
single-architecture. The corrected check requires the selected CPU in the GUI slices
and requires the helper to be exactly package-native, matching the trusted producer
inventory instead of weakening architecture validation.

Third branch run `35362624156` passed trust, installation, visible-window and screenshot
checks for the prior app on both CPUs, then refused to infer Quit when the first AX
helper could not find the menu command. It did not install the current package and its
failure cleanup left no owned process or state. The corrected helper restricts status
items to the exact app PID, prefers `AXPress` so `tray_manager` receives its real icon
click callback, searches the status item/menu-bar/app accessibility roots, and retains
bounded element/action diagnostics on another refusal.

Final branch run `35363132033` passed at qualification source
`2f036ea94fed5f485d8f63c36ba9b948b98db8ae`: native x64 job `105659084181` and
arm64 job `105659084218`. Each job reverified the retained successful producer runs,
accepted the 1.8.4 source through squash-merged PR #1503, validated exact DMG digests,
Developer ID identity, tickets, Gatekeeper, sealed versions/builds and package-native
helper CPU, then performed real `1.8.4+24 → 1.9.0+62` replacement in Applications.
Both prior/current launches rendered the signed-out window, invoked the exact app-owned
AX menu item `Quit Sesori`, exited without relaunch/orphans, and preserved Bridge Off,
desktop/shared-data/attachment sentinels and a valid login registration. The four
screenshots were inspected as rendered rather than inferred from window existence.

Evidence artifacts `10554589107` (x64) and `10554949003` (arm64) expire on
2026-10-02. Prior/current DMG hashes were respectively
`e0ee205da412828e667cd63653e92005986e926275b9fcc992e05d78415bbe7f` /
`54eab0a8fa1538401ce49820c92edd449e9b59df9aaef8ae9c4f6a38586e67a3`
for x64 and `27de5e5c8cfc15ed707c199d193b202fe0aec45c69abd5985f7c23ea129fda16` /
`ae287512772a4c2dd313f68f52eec14526222704b3a67ba50c7c6ed9af724e24`
for arm64. Locally downloaded evidence was independently checked in
`build/desktop-macos-upgrade-evidence/native-2f036ea/verified-summary.json`.
This closes only private signed helper-Off replacement; authenticated helper-On,
failed-stop refusal, real-account/Keychain/TCC, minimum-OS, public retrieval and parent
Gate C remain open.

## Verification

Run the new Python tests and the directly affected existing desktop tooling tests;
validate changed workflows with actionlint and whitespace/Markdown links. No Dart,
Flutter, signing, native app, live bridge or publication operation is needed locally.
A trusted private Actions preparation can be exercised only against a new successful
producer run that uploads channel evidence; historical runs do not supply that input.

Local implementation checkpoint: `d72b0c9c7945794cbec2eed7fe4c3eba976d6ba7`.
Before commit, the desktop Python discovery suite passed 31 cases. Two additional
identity/inventory rejection tests were then added; the resulting focused preparation
suite passed all 9 cases. Changed workflows passed actionlint. Those inputs were
committed unchanged. No Git tree was captured at the time of these pre-commit
runs, so they are not claimed as exact-checkpoint measurements. Commands, all from
`/Users/alexandrudochioiu/sesori-ai/sesori_apps_monorepo/.worktrees/tan-antelope`:

- `python3 -m unittest discover -s .github/scripts -p 'test_*desktop*.py'`:
  exit 0, 31 cases, `tests.log`, before the final two test methods existed.
- `python3 -m unittest discover -s .github/scripts -p 'test_prepare_desktop_release.py'`:
  exit 0, 9 cases, `preparation-tests-final.log`, after those methods were added.
- `actionlint .github/workflows/desktop-release.yml .github/workflows/desktop-qualification.yml
  .github/workflows/release-workflow-ci.yml`: exit 0, `actionlint.log`.
- `git diff --check`: exit 0; no separate historical log captured.
- A Python Markdown-link check resolved relative Markdown targets against each
  document's directory: passed; no separate historical log/script captured.
  This was a local sanity check, not an independently reproducible saved test.

Logs live in
`build/desktop-release-preparation-evidence/` (`tests.log`, `actionlint.log`,
`preparation-tests-final.log`). These are synthetic/offline tests, not a successful
Actions preparation or native/public-release evidence. No signing credentials were
used and no local bridge/app process was touched.

Review correction measured **after commit** at
`d5f4b457ab0e8f2621c7a23e6b443a31b040d2b3`, tree
`5f0c4722941522f106137685bf2a68d9749bc90f`, from the same cwd:

- `python3 -m unittest discover -s .github/scripts -p 'test_prepare_desktop_release.py'`:
  exit 0, 9 cases; `review-tests.log`.
- `actionlint .github/workflows/desktop-release.yml`: exit 0; `review-actionlint.log`.
- `git diff --check origin/main...HEAD`: exit 0; `review-whitespace.log`.

Exact commands/cwd/source are also in local `review-verification.json` beside those
logs. No test result is retroactively attributed to a later documentation commit.
