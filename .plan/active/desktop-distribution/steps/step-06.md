# Step 6 — Shared release cycle and desktop publication gate

Ordinal 8/14. Builds on merged step 5 (#1506). Private preparation is already merged.
The user selected the shared bridge/mobile release cycle on 2026-09-25. Continuation
`8.j/14` wires native macOS builds and gated asset attachment into that cycle without
changing the existing bridge/mobile finalizers or publishing a desktop release.

## Code-informed implementation boundary

- `.github/workflows/desktop-release.yml` remains manual and read-only. It downloads
  both CPUs' packages/evidence from one successful qualification/shared release run.
  Source SHA, run ID and channel are explicit inputs; this QA aid is macOS-only.
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

## Shared-cycle continuation and blockers

`release-all-platforms.yml` reuses the private macOS producer with its resolved
build number/source and internal channel. Desktop-only changes now enter the same
product cycle. `submit-release.yml` uses the resolved source/build with the stable
channel for admitted macOS releases; beta and `bridge-only` keep their existing scope.
Core mobile/bridge success conditions, tags, attempt recording and finalizers remain
unchanged. A desktop build failure stays visible without rolling back other products.

`_reusable-desktop-publish.yml` runs only after native desktop success and the shared
release job. Production therefore already passed `store-production`; no second
approval is added. `DESKTOP_MACOS_PUBLICATION_ENABLED` defaults off and is not enabled
by this change. Internal packages stay in Actions artifacts until the owner admits
macOS publication. Windows/Linux publishing is not enabled.

The publisher checks both native payload sets against producer evidence, binds them
to the shared version/build/source, and adds only four macOS installers plus
`desktop-checksums.txt` and `desktop-release.json`. It never changes bridge checksums,
creates/promotes releases, moves tags or changes Latest. It anonymously retrieves and
hashes each asset, refuses replacement on retries, and uploads the manifest last.
Private evidence, logs and screenshots are never attached to the public release.

Production's workflow commit is not its older resolved product source; both are
recorded. Own-run finalization admits an in-progress producer only for that exact run
and workflow SHA, after its native job dependency succeeds. Other selected runs must
be completed successfully. Upgrade probes also accept the shared producers while
retaining package-source main ancestry and the exact historical baseline exception.

Do not claim step 6 shipped from preparation. The owner-approved signing migration
is complete: all five values live only in `macos-signing`, shared CLI and direct
desktop native proof passed on both CPUs after repository-copy removal, and the
migration plan retired in #1534. Remaining gates:

- Remaining native/macOS and parent desktop-app checks. Authenticated/helper-Off
  replacement already passed for build 122 on both CPUs. Existing shutdown tests
  passed 82 cases; that is not packaged fault injection. The user reports desktop
  checklist success on M4 Pro/macOS 27.0 (26A428), with app build unspecified.
  The configured deployment minimum is macOS 12.0; execution on that minimum,
  remaining cross-device cases and fresh candidate attribution are still unproven.
- Verified public download links on `https://sesori.com/desktop/`. The page itself went
  live on 2026-09-18 (sesori-ai/landingpage#107) with all eight build anchors and
  `linux-package-managers`; every row is still an unshipped placeholder.
- Owner admission before enabling `DESKTOP_MACOS_PUBLICATION_ENABLED`, then actual
  immutable publication/public retrieval/trust checks before exposing website links.
  No publication credentials or hosted resources are provisioned here.

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
through stdin. The original trusted-app ACL included `/usr/bin/security`; the
signing-partition correction below replaces that credential-value access path.
It persists Bridge On, requires the exact packaged helper plus authenticated-profile and
relay-serving markers before each real tray Quit, and verifies Keychain/On intent and
bounded state through replacement with no relaunch or orphan. Raw auth responses,
Keychain values, bridge/app output and authenticated screenshots are excluded from
artifacts. The account and repository secrets are provisioned. Run `35443816334` reached
this exercise on both CPUs but each native job consumed the full 35-minute timeout after
prior-app installation, before any Keychain/session/report success evidence. Its bounded
artifacts are `10584848537` (x64) and `10586555281` (arm64); the run is rejected. The
`8.c/14` follow-up replaces create-then-change-ACL with atomic classic-Keychain creation,
retains the ACL during token refresh and bounds every native Keychain command. It merged
as source `55547f26c8a9f59747987f1b7a65fc473e76e9c2`, tree
`87fb1050b44566f9d456c21af16427823fbf60b2`. Merged-main run `35454870471` passed
tooling job `105928266878`, then x64 job `105928289095` and arm64 job `105928289036`
failed at their bounded prior-app helper deadline. Both bounded observations record zero
helper processes and no authenticated-profile or relay-serving marker. Evidence artifacts
are `10587393605` (x64, digest
`sha256:8d1d1f0af67d74bab0df5932aeb70b2d749c4bd5de6c24176fc017d1db184ca1`) and
`10588086362` (arm64, digest
`sha256:828eea306fec4d0e4d9a6942bddb462a2051fba5ca44bfa3956ec7786419fa5e`);
the run is rejected. The `8.d/14` correction matches the writer's item attributes to
the pinned FlutterSecureStorage query's explicit non-synchronizable
(`kSecAttrSynchronizable: false`) and when-unlocked values, then self-verifies that exact
lookup before launch. It merged as source
`bf14d7c0f32def581febd1531214bbdd2be9fd74`, tree
`ee65475efb25a2b0bad8121787fc5e38c37bc6d2`. Merged-main run `35460239311` passed
tooling job `105942674629`; reaching the helper wait proves exact Keychain self-checks
passed. X64 job `105942696871` and arm64 job `105942696897` still reached the bounded
prior-app helper deadline with zero final helper processes. Evidence artifacts are
`10588818277` (x64, digest
`sha256:96e4895178bb2f98b7ea93a57dc05b5662727518fc0b8fc905981f275d83dd03`) and
`10589833036` (arm64, digest
`sha256:62159a3eefe8f3cec3bac361212de3ea8f294a6dc462ddbafdd241388ee9edd6`); the run is
rejected. The `8.e/14` correction classifies a closed startup marker set from at most
1 MiB of phase-scoped private app output and records whether any helper generation or
fresh bridge-log activity appeared. The auth gate emits privacy-safe local-session
outcomes through the captured production log sink rather than relying on
`dart:developer`. It merged as source
`db9b0cd8bdf0e4b220d3f0fa069ec831e35f2a89`, tree
`20a3a04d3a3b5399f880cb46f79eb222e6e24f4f`. Merged-main run `35465783382` passed
tooling job `105957734614` but is rejected with conclusion `cancelled`. X64 job
`105957752803` remained in the exercise step through its job deadline and uploaded no
artifact. Arm64 job `105957752806` reached the prior-app helper deadline. Its artifact
`10591911157`
(`sha256:e4ee1899b990a5699e4127c86b83f9434a3e39ed90a808d3b6e308f734f03666`)
records no helper generation, fresh bridge-log activity or startup marker even though the
redirected output file exists. The `8.f/14` correction also scans at most 1 MiB of the
authoritative private persisted `logs/app.log`, writes an atomic closed phase record
before blocking boundaries, and bounds the exercise step below the job deadline so
always-upload can retain timeout evidence. Raw authenticated app/bridge output remains
excluded and cleanup removes it. It merged as source
`e231295f8b00a8f7a7055e943cc6f4502dfda13c`, tree
`2d24d147f9f2be55e8885c4e81d3fbb7ecd17672`. Merged-main run `35496105360` passed
tooling job `106039227037`, but x64 job `106039268281` and arm64 job `106039268268`
both reached `previous: authenticated helper did not become ready`. Their bounded
artifacts, respectively `10601325063`
(`sha256:4ac6d8e635f46d6f8774ac385bebe3c5514225c38132034cd0328de7ce7bc386`) and
`10601410119`
(`sha256:431fea30cc86113f9d5fe388a76a625a58bfc011475f515d894f9096f949de7d`),
each record helper-readiness as the failing phase, completed cleanup, zero helpers, no
helper/bridge-log activity, no persisted app log, and present non-truncated redirected
output with all classified markers false. The `8.g/14` correction adds fixed pre-sink
Dart-main and process-admission markers, emits only the furthest closed startup stage
observed within the same bounded private sources, and separately records package marker
support from checked-out source or exact retained-baseline metadata. Baseline run
`35042335424` supports `preferences` through `rendering`, not the new pre-sink markers;
its `noMarker` means only "before the first supported marker". This merged as #1564,
source `33a4ceb5506349d08953be37ba7d3a5f1d6d20df`, tree
`08f1d7b283faec4985a78b78ae8e7b7e4433dee9`.

### Fresh packages and rejected authenticated retry

Stable macOS package run `35501361734` passed both CPUs at that source/tree for
`1.9.0+122`; both app/DMG notarizations were accepted and source patches empty.
No publication was attempted. Tooling job: `106053576778`.

- X64 job `106053597551`, evidence `10602722410`:
  `sha256:cf589543df21681b415956db846992d547f124a2a633c898494cbf88bb1cc58b`.
  Package artifact `10602617512`:
  `sha256:ddb61da09e3b051876383d9de470e631429d0efdaeab10a7aa9a6f60d4662c65`.
  DMG: `99dfc8a194fe286c98a4dca3adf53b90936f6e172e4fca92ab9562d6208f6184`.
  ZIP: `71f9a2c733e20cc013f33042ba9bf80b0920063404f93f832d61840ee3d8200d`.
- Arm64 job `106053597564`, evidence `10602283403`:
  `sha256:d48dce904bc8509232ab38d7a473f7c0523c3ae66e4fe68c8014350674066bda`.
  Package artifact `10601849265`:
  `sha256:a4c30484ce99426d715b7d37adf0f610384ee4f87a909b352b18e3c2d610407a`.
  DMG: `7b5329305da33a473a5687351befeb442f703dd07f69105f9d4635c74bc3e19d`.
  ZIP: `630b2731c994531b6d41e2d952fb1141257aa5ead12e97c423286a03d185365b`.

Retry `35502787779`, at the same tooling source, paired these packages with baseline
`35042335424`. Tooling job `106057422791` passed; both native jobs failed:

- X64 job `106057447920`, artifact `10603060838`:
  `sha256:0a8336768ce4ed0b47916c3cff78756cac0b8d8c965266b5d149650b947bc216`.
- Arm64 job `106057447951`, artifact `10603335432`:
  `sha256:c9bc0d6cdb43e431e8f54c174b6331a0e22b5b6782b00435191d3cf5620db0ac`.

Both verified archives report `previous` / `helperReadiness`, completed cleanup,
zero helpers/activity, and `preRender` / `desktopAttention`. Redirected output exists,
but no persisted log or current-candidate evidence. Replacement never began; this does
not demonstrate an upgrade regression. Only bounded allowlisted JSON was inspected.
Older run `35496105360`'s archives `10601325063` and `10601410119` were mistakenly
deleted during investigation, as was their local directory. Recorded IDs/digests and
observations survive; do not claim those archives remain available. No credential leak
was established: the misclassified launcher file captures `open(1)`, not app output.

### Signing-partition correction — ordinal 8.h/14

After the pause, the user directed continued work through Step 8 with careful diagnosis
and cost-effective local tests. They expressly allowed disposable dummy-only Keychains,
without changing the login/default Keychain or search list, launching Sesori, or touching
existing app/bridge state. Those restrictions were preserved, and every created Keychain
was deleted. Tests used explicit `kSecUseKeychain` / `kSecMatchSearchList` handles and
non-interactive readers; default/search-list comparisons remained equal.

The fast native reproducer used the current seeder calls and pinned
`flutter_secure_storage_darwin` 0.4.2 native read implementation, modified only to target
the disposable Keychain. Swift readers disabled interaction. A file outside
`~/Library/Keychains` has no partition ACL and
incorrectly suggests cross-process access is fine. A uniquely named disposable file
inside that directory has a partition ACL: self-read succeeds, but a different ad-hoc
reader in the trusted-app ACL returns `errSecAuthFailed` (`-25293`). A byte-identical
second executable, sharing the signing partition, reads the exact dummy value through
the same native plugin. This isolates a real harness defect; it is not a local launch
of either signed product or proof that all later CI gates pass.

Apple's `securityd/src/clientid.cpp` assigns Developer ID processes their signing team's
partition independently of the item trusted-app list. Sign the QA helper with the same
existing Developer ID as both apps rather than manually rewriting partition ACLs. The
helper checks both Developer ID signatures and team equality before Keychain access.
Use it for private verification reads too; `security -w` has a separate partition.
Keep exact-app ACLs, stdin-only writes, private captured reads, and 15-second deadlines.
The main-only `macos-signing` step uses existing credentials, bounded to three minutes;
it removes signing material before the separate QA-secret exercise step. It needs no
notarization credentials and neither embeds nor publishes the helper with the product.
No production startup code, new signing identity, schema, persistent state or lifecycle
coordination is introduced. Local signing keys are not accessed.

Initial local verification, on the **uncommitted worktree before** PR commit
`0b5a0027d51fcbbbe6f0063bd44ee5f99b3a100b`: 38 focused authenticated-upgrade tests
(included in 118 passing desktop Python tests), five signing-workflow tests, Swift
compilation, bash syntax and actionlint passed. No source/tree hash was captured for
those measurements; they are not exact-checkpoint evidence. Output was captured in the
Pi session, with no separate durable log files. All commands ran from
`/Users/alexandrudochioiu/sesori-ai/sesori_apps_monorepo/.worktrees/tan-antelope`:

```bash
python3 -m unittest discover -s .github/scripts -p test_qualify_desktop_macos_authenticated_upgrade.py
python3 -m unittest discover -s .github/scripts -p 'test_*desktop*.py'
python3 -m unittest discover -s .github/scripts -p test_macos_signing_workflows.py
bash -n .github/scripts/macos_signing_ci.sh
xcrun swiftc -suppress-warnings .github/scripts/write_desktop_macos_keychain.swift \
  -framework Security -o build/desktop-keychain-local/signed-policy-writer
actionlint .github/workflows/desktop-qualification.yml
```

The compiled unsigned helper refused before Keychain access with `OSStatus -67050` and
empty stdout. Initial signing-workflow tests used stubs for secret separation,
signer/requirement arguments and signing-material cleanup; they did not test the real
`codesign` requirement parser or claim Developer ID signing. Review identified the
missing `=` literal-text prefix, which otherwise makes `codesign` interpret the
requirement as a filename. The correction uses `-R` with a literal requirement pinned
to publisher `AQNCF7663C`, independent of the configured signing team, and adds native
Apple-binary acceptance / publisher-mismatch rejection controls on macOS. No Dart/Flutter
suite or live app was run.

A separate review-time disposable-Keychain control removed `security` from the item
trusted-app list. The cross-partition pinned plugin read still failed (`-25293`), while
`security find-generic-password` without `-w` succeeded, `delete-generic-password`
succeeded, and the final lookup returned item-not-found (CLI exit `44`). Therefore
metadata checks/deletion retain their existing owner; no new signed-delete operation or
app-lifetime dependency is needed. The local bounded result is
`build/desktop-keychain-local/probe.0f4jtM/cleanup-control.json`; the standalone fixture
used explicit scratch-Keychain handles, preserved default/search-list settings, and
removed its Keychain in `finally`. This control is not product acceptance evidence.
The review corrections' five signing-workflow tests (including the real native parser
controls), bash syntax and diff checks passed on an uncommitted worktree above `0b5a002`.
Commands, base commit, measured diff digest and separate logs are recorded locally in
`build/desktop-keychain-local/review-1571/verification.json`; the cwd is the same as above.
Unchanged Dart/Flutter, desktop Python and Swift compilation checks were not repeated.

### Accepted build-122 replacement and preparation — ordinal 8.i/14

PR #1571 merged on 2026-09-21 as
`fe5df8e9152688c76eab127eac6c615547effd29`, tree
`2549a8a964f534f462f5139d97aeaa15c925f73b`. All three runs below executed from that
merged-main tooling revision. They reuse the unchanged retained baseline `35042335424`
(`1.8.4+24`, source `efefcbcff7e7b75bdde271c1c670333987530212`, tree
`d0f1d0e3cfb31090d0ddb6d5b8321604e7e65730`) and current package run `35501361734`
(`1.9.0+122`, source `33a4ceb5506349d08953be37ba7d3a5f1d6d20df`, tree
`08f1d7b283faec4985a78b78ae8e7b7e4433dee9`). No product rebuild or startup change was
needed after the demonstrated signing-partition fixture correction.

Dispatches ran from
`/Users/alexandrudochioiu/sesori-ai/sesori_apps_monorepo/.worktrees/tan-antelope`:

```bash
gh workflow run desktop-qualification.yml --repo sesori-ai/sesori_apps_monorepo \
  --ref main -f mode=macos-authenticated-upgrade-probe -f channel=stable \
  -f previous_packaging_run=35042335424 -f packaging_run=35501361734
gh workflow run desktop-qualification.yml --repo sesori-ai/sesori_apps_monorepo \
  --ref main -f mode=macos-upgrade-probe -f channel=stable \
  -f previous_packaging_run=35042335424 -f packaging_run=35501361734
gh workflow run desktop-release.yml --repo sesori-ai/sesori_apps_monorepo \
  --ref main -f source_sha=33a4ceb5506349d08953be37ba7d3a5f1d6d20df \
  -f packaging_run=35501361734 -f channel=stable
```

Each run had exactly one asynchronous `gh run watch <run> --repo
sesori-ai/sesori_apps_monorepo --exit-status`, followed by one terminal metadata query.
All watches returned zero and every actual workflow HEAD matched the tooling SHA above.
Archive bytes were fetched with `gh api repos/sesori-ai/sesori_apps_monorepo/actions/artifacts/<id>/zip`
and their SHA-256 digests matched the Actions artifact metadata. Only the allowlisted
bounded records described below were inspected; archives were not extracted or retained.

#### Authenticated helper-On acceptance

Run [35573213361](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/35573213361)
passed tooling job `106249150117` and both serialized native jobs:

| CPU / runner | Job | Evidence artifact |
|---|---|---|
| x64 / `macos-26-intel` | `106249218337` | `10627117175` |
| arm64 / `macos-26` | `106249218239` | `10626568356` |

Verified archive digests:

- x64: `sha256:c470d27cea880a58522c35ba64e4b959e8f9fae122f04680674c158c0bf4b0da`.
- arm64: `sha256:1de7e6543fa1bef7691d755e9456e85dc9a504f3ba2584aa91d159cbe2db849f`.

On each CPU, `authenticated-upgrade.json` records all 15 checks true. Both
`previous-authenticated-helper.json` and `current-authenticated-helper.json` record
exactly one live helper, observation during readiness polling, fresh bridge-log activity,
authenticated-profile confirmation and relay-serving readiness. All four launches
therefore crossed the formerly blocked baseline/current boundary. Both final
`qualification-phase.json` records are `complete`, with null candidate and
`cleanupStarted` / `cleanupCompleted` true. Each inspected JSON entry was capped at 8 KiB
and its schema, identities and closed values validated. No raw auth response, credential,
app/bridge log or authenticated screenshot was opened or retained.

This accepts real signed helper-On replacement: private Keychain/session verification,
On intent, exact helper readiness, real tray Quit stopping that helper, no relaunch/orphan,
and bounded desktop/shared-data/attachment/login-registration preservation. It does not
convert the old failed runs into passing evidence or prove every previous symptom's cause.
Local bounded summary:
`build/desktop-macos-authenticated-upgrade-evidence/source-35573213361/verified-summary.json`.

#### Helper-Off acceptance for the same packages

Run [35575012582](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/35575012582)
passed tooling job `106254787937` and both native jobs:

| CPU / runner | Job | Evidence artifact |
|---|---|---|
| x64 / `macos-26-intel` | `106254857475` | `10628415220` |
| arm64 / `macos-26` | `106254857531` | `10628285309` |

Verified archive digests:

- x64: `sha256:96ba19884e573150d63ca917f73e52becccc6d095e39ea0f56fcdf02aa6b5fde`.
- arm64: `sha256:1d815299a2f4e23726b13f580669555385ef2265d58fb5614f777b12283b508f`.

Both `upgrade.json` reports have all 11 checks true, including
`helperAbsentBeforeQuit`. Each prior/current `*-helper-off.log` is exactly the closed
`NO_INSTALLED_HELPER` marker. Report and marker entries were bounded to 8 KiB; no other
log or screenshot was inspected. Both candidates' run/source/build/DMG identities match
the accepted authenticated reports exactly. This qualifies build `122` directly rather
than borrowing historical build-62 acceptance.
Local bounded summary:
`build/desktop-macos-upgrade-evidence/source-35575012582/verified-summary.json`.

#### Regenerated read-only preparation

Run [35575015316](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/35575015316),
job `106254795658`, passed. Artifact `10627179861` has verified digest
`sha256:19fab4ad96ff29f39251da4459ff03007eade06ea1f9872a036389aeab4246aa`.
Its bounded `desktop-release.json` and `checksums.txt` agree on all four previously
verified DMG/ZIP hashes, stable `1.9.0+122`, proposed tag `desktop-v1.9.0`, and
`githubLatest: false`. Package source `33a4ceb5506349d08953be37ba7d3a5f1d6d20df` / run
`35501361734` remains distinct from preparation source
`fe5df8e9152688c76eab127eac6c615547effd29`. The workflow revalidated both packages'
compiled identity/channel, clean source, accepted notarization receipts and inventories.
This is fresh consistency preparation for build `122`, not transferred build-62 evidence,
independent signature verification or release approval. No tag, release, hosted payload,
channel metadata or website link was published.
Local bounded summary:
`build/desktop-release-preparation-evidence/source-35575015316/verified-summary.json`.

The acceptance-record change is documentation-only. Failed-stop refusal, interactive
browser/login/TCC, real harness/chat and phone/CLI coexistence, login/autostart and
close-to-tray behavior, minimum-OS, public retrieval and parent Gate C remain open.
Sentinels prove only the exercised bounded preservation, not arbitrary user histories.
These private passes do not complete the public portion of step 6 or authorize shipment.

### Historical dispatch and log commands

Earlier dispatches and expanded logs were run from
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
