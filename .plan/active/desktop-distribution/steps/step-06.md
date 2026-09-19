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
The first correction snapshot process-owned AXMenu elements before AXPress and accepted
only a newly appeared menu anchored to the clicked status item, then searched for Quit
only inside it. Second main-only run `35375073067` used accepted source
`db12c5df7e1dff2a62c10b036c75fdcc13e6a727`, tree
`91964b2e117ec314a4a79ebbe8b85f48d1d588be`. Arm64 job `105697793343` and x64 job
`105697793591` both failed safely at prior-version Quit. Arm64 already exposed 16 menu
elements before the press, so novelty could not identify the tray menu. On x64 the
hierarchy traversal invalidated the status-item reference before its action was read.
Neither job installed the current package; cleanup removed probe-owned app/state.

The second correction recorded the status-item frame/actions immediately, required
AXPress and used application-scoped hit testing beside the frame. Third main-only run
`35384845467` used accepted source `9258270896ca5d95d74b084f15789a8132e55d95`,
tree `0bb665f8913aebaabe5886b1228885f7c961b252`. X64 job `105729297682` and arm64
job `105729297693` both failed safely at prior-version Quit because application-scoped
hit testing did not surface the status-bar menu. Neither installed the current package;
cleanup removed probe-owned app/state.

The third correction used system-wide z-order hit testing while requiring exact PID,
AXMenu role, frame anchoring and menu-bounded Quit lookup. Fourth main-only run
`35391748404` used accepted source `f6cc2f0cccdd13db1f067f8914bfab3c9a9a437f`,
tree `39b10f019514c5623a6bf1b6a0ef30a399d5d8ec`. Arm64 job `105751519510` and x64
job `105751519532` both failed safely at prior-version Quit: sample points saw only
AXGroup/AXWindow elements, showing AXPress did not expose the custom-view popup.
Neither installed the current package; cleanup removed probe-owned app/state.

The next correction validated the process-owned status frame as 4–100 points wide,
4–64 points high and inside the top 80 screen points, then posted one real mouse click at
its center so `tray_manager` received its custom NSView mouse-down callback. System-wide
hit testing and exact PID/AXMenu/frame/menu-bounded-Quit admission stayed unchanged. It
merged in PR #1541 as `75a3e8c49be647ff663ea05207ed1badaa14db28`.

Fifth main-only run `35399491087` used that accepted source, tree
`9724e3a2de1c31cfb4ca0fa3284aa423a8266b86`. Arm64 job `105775932697` passed the
complete replacement with all `upgrade.json` checks true and evidence artifact
`10569173343`. X64 job `105775932698` passed prior-app Quit and current installation and
launch, but its only current-window sample at 15 seconds found no visible main window.
Unchanged retry `35399933745` reproduced the boundary: arm64 job `105777334558` passed
with artifact `10569088925`, while x64 job `105777334570` again reached current launch
but single-sample window inspection failed. Both failed x64 jobs cleaned probe-owned
app/state and uploaded evidence artifacts `10568978583` and `10569029230`.

The next correction retained the 15-second process-survival check and retried the
read-only owned-window inspector for 45 additional bounded seconds. It records every
attempt and still refuses an inactive screen, exited process, hung inspector or final
absence. It merged in PR #1542 as `305998d689d13051ac0fb58f9d970dfffe319bf0`.

Main-only run `35405646668` used that accepted source, tree
`a6f358647c559b840f1c3ecade88be1502632a57`, and completed successfully. X64 job
`105794893362` and arm64 job `105794893463` both recorded every `upgrade.json` check
true for signed/notarized package trust, real prior/current visible startup and tray
Quit, no relaunch/orphan, complete replacement, Bridge Off intent and bounded
state/login-registration preservation. Evidence artifacts are `10571804180` (x64,
digest `bc9ac73ebf451a400280a8b8e3c478eba3e67013d64a2a79e77e6877b47a7fc4`) and
`10571709031` (arm64, digest
`c7663919c1da5ff531c7103834c6e292f0b962d8ad0a73519f429a58f378876d`), expiring
2026-10-02. That run accepted private signed replacement with persisted Bridge Off
intent on both CPUs, but did not inspect helper absence while either GUI was running.

The live helper-Off correction checks the exact
`/Applications/Sesori.app/Contents/Helpers/bridge/bin/bridge` process after each
visible prior/current launch and before tray Quit. It preserves an explicit
`*-helper-off.log`, refuses a running helper, and adds `helperAbsentBeforeQuit` to
successful evidence. This credential-free check merged in PR #1546 as source
`8d99cd2925c9866dc121323ed348b0d130bc6aca`, tree
`777f3a353ff04eaeab29f6a6ff3f81e514b04cf1`. Main-only run `35411687826` passed
tooling job `105812432480`, x64 job `105812464127` and arm64 job `105812464132`.
Evidence artifacts are `10574093842` (x64, digest
`sha256:a2016249efcc4aa3edda7d6a5e0097a1e5904c15cd78975bb8437fb7e055a6a2`, expiring
2026-10-03T01:11:05Z) and `10574368671` (arm64, digest
`sha256:ff848668381813e9318d97a572eb3520f4c6267b0bb39d8abb668f486d2a207e`, expiring
2026-10-03T01:10:24Z). Both prior/current helper logs on both CPUs record
`NO_INSTALLED_HELPER`; every implemented report check is true. Private helper-Off is
accepted on both CPUs. PR #1547 recorded that accepted boundary and merged as
`1ff3780b0b9244f5dada842c9e7735a28712fb2d`.

The separate `macos-authenticated-upgrade-probe` merged in PR #1548 as
`cb23a7fc5d1f5b4fcedd1de2d591f88fd4074d43`, restricted to `main` and initially bound
to the `desktop-qa` environment. The owner-requested `8.b/14` follow-up removes that
environment binding and reads the provisioned `qa@sesori.com` account from repository
Actions secrets without an approval gate. Native CPU jobs are serialized so they cannot
compete for that account's one relay bridge slot. Credentials
are provided only to the exercise step, then consumed and removed from the environment
before any child process. The script requests phase-fresh tokens in memory, writes
`access_token`, `refresh_token` and `auth_user` to the established
`com.sesori.desktop` classic-Keychain service
through stdin, and trusts only the installed signed app plus `/usr/bin/security`.
It persists Bridge On, requires the exact packaged helper plus authenticated-profile and
relay-serving markers before each real tray Quit, and verifies Keychain/On intent and
bounded state through replacement with no relaunch or orphan. Raw auth responses,
Keychain values, bridge/app output and authenticated screenshots are excluded from
artifacts. The account and repository secrets are provisioned. Run `35443816334` reached
this exercise on both CPUs but each native job consumed the full 35-minute timeout after
prior-app installation, before any Keychain/session/report success evidence. Its bounded
artifacts are `10584848537` (x64) and `10586555281` (arm64); the run is rejected. The
`8.c/14` follow-up replaces create-then-change-ACL with atomic classic-Keychain creation,
retains the ACL during token refresh and bounds every native Keychain command. Only a
both-CPU retry dispatched from merged `main` can become evidence. Failed-stop,
interactive browser/user-account/TCC, minimum-OS, public retrieval and
parent Gate C remain open.

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
gh workflow run desktop-qualification.yml --repo sesori-ai/sesori_apps_monorepo \
  --ref main -f mode=macos-upgrade-probe -f channel=stable \
  -f previous_packaging_run=35042335424 -f packaging_run=35206885114
gh run view 35375073067 --repo sesori-ai/sesori_apps_monorepo --job 105697793343 --log
gh run view 35375073067 --repo sesori-ai/sesori_apps_monorepo --job 105697793591 --log
gh workflow run desktop-qualification.yml --repo sesori-ai/sesori_apps_monorepo \
  --ref main -f mode=macos-upgrade-probe -f channel=stable \
  -f previous_packaging_run=35042335424 -f packaging_run=35206885114
gh run view 35384845467 --repo sesori-ai/sesori_apps_monorepo --job 105729297682 --log
gh run view 35384845467 --repo sesori-ai/sesori_apps_monorepo --job 105729297693 --log
gh workflow run desktop-qualification.yml --repo sesori-ai/sesori_apps_monorepo \
  --ref main -f mode=macos-upgrade-probe -f channel=stable \
  -f previous_packaging_run=35042335424 -f packaging_run=35206885114
gh run view 35391748404 --repo sesori-ai/sesori_apps_monorepo --job 105751519510 --log
gh run view 35391748404 --repo sesori-ai/sesori_apps_monorepo --job 105751519532 --log
gh workflow run desktop-qualification.yml --repo sesori-ai/sesori_apps_monorepo \
  --ref main -f mode=macos-upgrade-probe -f channel=stable \
  -f previous_packaging_run=35042335424 -f packaging_run=35206885114
gh run view 35399491087 --repo sesori-ai/sesori_apps_monorepo --job 105775932697 --log
gh run view 35399491087 --repo sesori-ai/sesori_apps_monorepo --job 105775932698 --log
gh workflow run desktop-qualification.yml --repo sesori-ai/sesori_apps_monorepo \
  --ref main -f mode=macos-upgrade-probe -f channel=stable \
  -f previous_packaging_run=35042335424 -f packaging_run=35206885114
gh run view 35399933745 --repo sesori-ai/sesori_apps_monorepo --job 105777334558 --log
gh run view 35399933745 --repo sesori-ai/sesori_apps_monorepo --job 105777334570 --log
gh workflow run desktop-qualification.yml --repo sesori-ai/sesori_apps_monorepo \
  --ref main -f mode=macos-upgrade-probe -f channel=stable \
  -f previous_packaging_run=35042335424 -f packaging_run=35206885114
gh run view 35405646668 --repo sesori-ai/sesori_apps_monorepo --job 105794893362 --log
gh run view 35405646668 --repo sesori-ai/sesori_apps_monorepo --job 105794893463 --log
gh workflow run desktop-qualification.yml --repo sesori-ai/sesori_apps_monorepo \
  --ref main -f mode=macos-upgrade-probe -f channel=stable \
  -f previous_packaging_run=35042335424 -f packaging_run=35206885114
gh run view 35411687826 --repo sesori-ai/sesori_apps_monorepo --job 105812464127 --log
gh run view 35411687826 --repo sesori-ai/sesori_apps_monorepo --job 105812464132 --log
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
