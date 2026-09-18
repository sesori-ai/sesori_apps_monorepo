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
- Verified public download links on `https://sesori.com/desktop/`. The page itself went
  live on 2026-09-18 (sesori-ai/landingpage#107) with all eight build anchors and
  `linux-package-managers`; every row is still an unshipped placeholder.
- Actual immutable publication and public retrieval/signature checks, then channel
  metadata last. No publication credentials or hosted resources are provisioned here.

No automatic updater layers remain to clean up. The private producer stays separate
from public release authority. Windows/Linux publication remains disabled.

## Post-migration continuation

Stable package run `35206885114` used source
`7aecbd943671290eca53506949a9c38f2d8da4d0`, tree
`497c66e6407b9ca25a998fc60dab4679377ad233`, and passed x64 job `105154787465`
and arm64 job `105154787487`. Read-only preparation run `35359083211` used tooling
source `beb99dc35e18ecbe596753ba7353237a817acf87`, tree
`8b5fd10865a37ae2e5f0b1a10642e02b98981ca6`, while retaining that exact package
source/tree. It proposed `desktop-v1.9.0`, build 62, without publishing.

The continuation adds credential-free, main-only `macos-upgrade-probe` qualification.
It accepts ordinary sources only from `origin/main`; the sole older exception is exact
retained run `35042335424`, source
`efefcbcff7e7b75bdde271c1c670333987530212`, tree
`d0f1d0e3cfb31090d0ddb6d5b8321604e7e65730`, with pinned merged-PR provenance.
It verifies package trust, performs actual DMG replacement and tray Quit, rejects
relaunch/orphans, and checks bounded desktop/shared-state plus login registration.

Branch diagnostics converged without being reclassified as accepted evidence:

- `35361626933` rejected the squash-merged retained source before package execution.
- `35362043592` exposed the universal-GUI/package-native-helper topology before copy.
- `35362624156` reached the prior visible app but refused to infer an unobserved Quit.
- `35363132033`, source `2f036ea94fed5f485d8f63c36ba9b948b98db8ae`,
  tree `713b3844b0f1c204b996ed80f3182bb921f509bf`, completed x64 job
  `105659084181` and arm64 job `105659084218`, but its broad Quit-item search could
  select the pre-existing application main menu and is not accepted evidence.

Run `35363132033` artifacts `10554589107` (x64) and `10554949003` (arm64) expire
2026-10-02. Prior/current DMG hashes were respectively
`e0ee205da412828e667cd63653e92005986e926275b9fcc992e05d78415bbe7f` /
`54eab0a8fa1538401ce49820c92edd449e9b59df9aaef8ae9c4f6a38586e67a3`
for x64 and `27de5e5c8cfc15ed707c199d193b202fe0aec45c69abd5985f7c23ea129fda16` /
`ae287512772a4c2dd313f68f52eec14526222704b3a67ba50c7c6ed9af724e24`
for arm64.

First main-only run `35367589565` used accepted source
`e8e2e328675707d0d4c64ab083a6c0bc533c7d13`, tree
`c070c5520b11cfde1f6b5596697c4fd2f37360a9`. Arm64 job `105673774002` and x64
job `105673774047` both failed safely at the prior-version Quit step: AppKit exposes
`tray_manager`'s transient menu outside the status item's child tree. Neither job
installed the current package, and final cleanup removed its probe-owned app/state.
The follow-up snapshots exact process-owned Quit items before AXPress, traverses the
bounded app/extras/status hierarchy afterward and accepts only a newly exposed item.
That preserves causal tray-menu proof while excluding the pre-existing application
main menu. A new main run is required. Authenticated helper-On, failed-stop,
real-account/Keychain/TCC, minimum-OS, public retrieval and parent Gate C remain open.

Dispatches and expanded logs were run from
`/Users/alexandrudochioiu/sesori-ai/sesori_apps_monorepo/.worktrees/tan-antelope`:

```bash
gh workflow run desktop-qualification.yml --repo sesori-ai/sesori_apps_monorepo \
  --ref main -f mode=macos-packaging -f channel=stable
gh workflow run desktop-release.yml --repo sesori-ai/sesori_apps_monorepo \
  --ref main -f source_sha=7aecbd943671290eca53506949a9c38f2d8da4d0 \
  -f packaging_run=35206885114 -f channel=stable
gh workflow run desktop-qualification.yml --repo sesori-ai/sesori_apps_monorepo \
  --ref desktop-distribution-macos-upgrade-probe -f mode=macos-upgrade-probe \
  -f channel=stable -f previous_packaging_run=35042335424 \
  -f packaging_run=35206885114
gh run view 35206885114 --repo sesori-ai/sesori_apps_monorepo --job 105154787465 --log
gh run view 35206885114 --repo sesori-ai/sesori_apps_monorepo --job 105154787487 --log
gh run view 35359083211 --repo sesori-ai/sesori_apps_monorepo --job 105645579449 --log
gh run view 35363132033 --repo sesori-ai/sesori_apps_monorepo --job 105659084181 --log
gh run view 35363132033 --repo sesori-ai/sesori_apps_monorepo --job 105659084218 --log
gh workflow run desktop-qualification.yml --repo sesori-ai/sesori_apps_monorepo \
  --ref main -f mode=macos-upgrade-probe -f channel=stable \
  -f previous_packaging_run=35042335424 -f packaging_run=35206885114
gh run view 35367589565 --repo sesori-ai/sesori_apps_monorepo --job 105673774002 --log
gh run view 35367589565 --repo sesori-ai/sesori_apps_monorepo --job 105673774047 --log
```

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
