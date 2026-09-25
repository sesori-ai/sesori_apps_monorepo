# Desktop Distribution — Tracker

Status values: `pending`, `in-progress`, `done`, `blocked`. Evidence belongs with
its completed step; this table tracks implementation, not transient PR reviews.

## Delivery

| Step | PR ordinal | Scope | Status |
|---|---|---|---|
| 1 | 1 | Align platform distribution and update plan | done |
| 2 | 2 | Qualify six-target packaging prerequisites | done |
| 3.a | 3 | Bind desktop builds to bundled bridge identity | done |
| 3.b | 4 | Surface packaged helper repair guidance | done |
| 4.a | 5 | Package and notarize native macOS builds | done |
| 4.b | 6 | Keep desktop startup independent of native notifications | done |
| 5 | 7 | Offer manual macOS updates through official downloads | done |
| 6 | 8 | Shared-cycle integration in progress; macOS publication remains gated | in-progress |
| 7 | 9 | Private Windows installers merged; signing/publication gated | blocked |
| 8 | 10 | Manual Windows release/winget requires signed public assets | blocked |
| 9 | 11 | Private native DEB/RPM packages merged; signing/publication gated | blocked |
| 10 | 12 | Shipped-download onboarding requires genuine public releases | blocked |
| 11 | 13 | Reconcile private distribution coverage; public closeout remains gated | in-progress |
| 12 | 14 | Verify six-target releases and retire distribution plan | blocked |

Exact PR titles, dependencies and the 14-PR total live in [PLAN.md](PLAN.md).
Stable IDs 1, 2, 3.a, 3.b, 4.a, 4.b, 5…12 map to PR ordinals 1…14. Platform ship gates
remain checkpoints within original steps 6, 8 and 9, not additional PRs.

## Current continuation — shared release cycle (2026-09-25)

The user selected the existing bridge/mobile cycle for desktop. Continuation
`🚧 [desktop-distribution] Join the shared product release cycle [step 8.j/14]`
reuses native macOS packaging with the aligned source/build, retaining existing
core finalizers and `store-production` approval. Desktop-only changes now qualify
for the scheduled product cycle. Publication stays disabled until explicit platform
admission; no separate scheduler, desktop tags, approval environment or credentials.
Fresh native verification of the shared producer remains pending merge.

Evidence reconciliation:

- The user reports the desktop checklist passing on **Apple M4 Pro / macOS 27.0
  (26A428)**. App version/build was not supplied; this is functional Apple Silicon
  confirmation, not Intel/minimum-OS coverage or source-specific release acceptance.
- The project defines `MACOSX_DEPLOYMENT_TARGET = 12.0` in all three configurations.
  Defining that minimum is distinct from exercising the product on macOS 12.
- The agent independently ran the existing bridge-control/process repository/service
  suites at `55781432391c042ebbbfe17a21d5e26083d4f4ba`: **82 tests passed**, with
  the running app/bridge untouched. Failed-stop refusal, waiting and retry are covered;
  native packaged fault injection is separate.
- Remaining parent Gate C checks are concrete: live harness install/login, dedicated
  sessions, image/permission/diff flows, relay-only recovery; phone-side request
  resolution clearing desktop alerts; one phone push; physical picker/microphone,
  shared session/navigation and notification regression. Do not repeat already-passing
  user checks or relabel automated fixtures as physical-device acceptance.
- Public admission, fresh candidate/native evidence, minimum-OS execution and website
  retrieval/trust remain gated. No desktop publication was approved or performed.

## Merged implementation history

Step 4.b merged as #1503: accepted `49694775e5d364a1316b767b66642531bf002e3a`,
squash `d1813409e3c0a8e053c3a28068d574e24fb70730`. All 11 checks settled at
acceptance (two skipped); all seven feedback threads resolved and Cubic approved.
Step 5 merged as #1506: accepted `3e890050bb1a55ee4d7e5c388afda67d0ae4384a`,
squash `256565719e0804a62e467c01368e6dab5254544c` at 2026-09-16T08:20:58Z.
All 19 checks passed at acceptance; Cubic approved and all threads were resolved.
The subsequent merged report showed an additional twentieth check running; it is
not included in the acceptance claim. Step 5 uses D6 manual updates and the
user-selected `https://sesori.com/desktop/`, live since 2026-09-18 with every row
still an unshipped placeholder. Details in
[step-05](steps/step-05.md). Step 6 preparation ran in the same worktree on
`desktop-distribution-release-channels`; publication remains gated.
Private preparation merged in #1511: accepted
`9b5d19c01480b0ee71732435955cf945d086abbc`, squash
`e91e1fc37cf308f228d3b0601781b62ebd465629` at 2026-09-16T09:36:49Z.
At acceptance 17/17 checks passed, Cubic approved, and all threads were resolved;
the merged report subsequently showed 18/18 passing. Public publication remains
blocked, not completed; see [step-06](steps/step-06.md). Independent private Windows
installer preparation ran on `desktop-distribution-windows-packaging` in the
same worktree. On 2026-09-16, private run 35097548359 at `a36896d051` passed native
x64/ARM64 compilation and silent install/reinstall/uninstall fixtures. Exact hashes,
source and proof boundaries are recorded in [step-07](steps/step-07.md); the earlier
run 35092987496 was cancelled, not passing or still running. This does not authorize shipping Windows
before the macOS gate.

Private Windows qualification merged in #1515, accepting
`99cdf2e8fc0e90e3f5cb08a151fd6871ccdcdd3f`, squash
`cc9c65932791f5dfa15954bdebe898d43324a51c` at 2026-09-16T15:30:55Z.
At acceptance 21/21 checks passed; the merged report subsequently showed 22/22.
All 19 feedback threads were resolved; final Cubic summary said all reported issues
were addressed. Final private native run
[35111369170](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/35111369170)
qualified both CPUs at exact accepted source
`99cdf2e8fc0e90e3f5cb08a151fd6871ccdcdd3f`, tree
`625b2cc9a5e900a8c6bb77f5bed3b340be7a7dd3`, 1.8.4/build 43. From this worktree
root, artifacts were retrieved with `gh run download 35111369170 --repo
sesori-ai/sesori_apps_monorepo --pattern 'desktop-windows-*' --dir
build/desktop-windows-packaging-evidence/native-99cdf2e`; downloaded installer hashes,
15-binary inventories, empty source patches and both fixture results matched. The
retained result is `build/desktop-windows-packaging-evidence/native-99cdf2e/verified-summary.json`;
its one-off summary command was not retained, so it is historical attribution rather
than a reproducible local tooling check. Signing and public Windows release remain
blocked. Step 8's download UI already
exists from step 5; winget manifests must wait for real signed public assets.
Rather than invent placeholder manifests, the series continued with private Linux
packaging on `desktop-distribution-linux-packaging`.

Private Linux qualification merged in #1522, accepting
`07bdd730e6451d221ebb86821a38c4252e4e0abc`, as squash
`9f9081f71995397edf39690efc212aa0920c6175` at 2026-09-16T17:05:04Z. Final private
run [35122448200](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/35122448200)
passed native x64 and ARM64 jobs at the accepted source. Its four DEB/RPM hashes,
73-file/13-ELF inventories, empty source patches and six Ubuntu 24.04, Debian 13 and
Fedora 44 fixtures were independently checked in
`build/desktop-linux-packaging-evidence/native-07bdd73/verified-summary.json`; exact
package hashes and proof limits live in [step 9](steps/step-09.md). At merge, all
reported required checks passed and the skipped platform-distribution jobs were
inapplicable to this Linux-only private run. Earlier failing attempts remain run
history, not unsupported product behavior or regression tombstones.

The macOS credential migration is complete: all five signing/notarization values are
now scoped to the main-only, approval-free `macos-signing` environment, their five
repository copies are absent, and both reusable CLI signing and direct desktop
preflight passed post-deletion on native x64/arm64. Fresh stable package run
`35206885114` then passed signed/notarized packaging, helper E2E, installed GUI and
platform fixture probes on both CPUs at source
`7aecbd943671290eca53506949a9c38f2d8da4d0`. Read-only preparation run
`35359083211` validated the four payloads as proposed `desktop-v1.9.0`, build 62;
it did not publish. Pre-merge implementation run `35363132033` at source
`2f036ea94fed5f485d8f63c36ba9b948b98db8ae`, tree
`713b3844b0f1c204b996ed80f3182bb921f509bf`, completed both CPU flows, but review
correctly rejected its broad Quit-item lookup as final evidence. First main-only run
`35367589565` at accepted source `e8e2e328675707d0d4c64ab083a6c0bc533c7d13`, tree
`c070c5520b11cfde1f6b5596697c4fd2f37360a9`, then failed safely at prior-version Quit
on arm64 job `105673774002` and x64 job `105673774047`: AppKit did not expose the
transient tray menu as a status-item child. Cleanup removed probe-owned app/state. The
follow-up snapshots process-owned AXMenu elements before AXPress. Second main-only run
`35375073067` at source `db12c5df7e1dff2a62c10b036c75fdcc13e6a727`, tree
`91964b2e117ec314a4a79ebbe8b85f48d1d588be`, failed safely on arm64 job
`105697793343` and x64 job `105697793591`: arm64 had 16 pre-existing menu elements but
no new accepted popup, while traversal invalidated x64's status-item reference before press. The
next correction requires AXPress first and uses app-scoped hit testing. Third main-only
run `35384845467` at source `9258270896ca5d95d74b084f15789a8132e55d95`, tree
`0bb665f8913aebaabe5886b1228885f7c961b252`, failed safely on x64 job
`105729297682` and arm64 job `105729297693`: neither app-scoped hit test surfaced the
status-bar menu. The follow-up used system-wide z-order hit testing. Fourth main-only
run `35391748404` at source `f6cc2f0cccdd13db1f067f8914bfab3c9a9a437f`, tree
`39b10f019514c5623a6bf1b6a0ef30a399d5d8ec`, failed safely on arm64 job
`105751519510` and x64 job `105751519532`: sampled points saw only AXGroup/AXWindow,
not an accepted popup. PR #1541 added one real mouse click to the strictly bounded
process-owned status frame while retaining exact PID/menu/frame/Quit admission; it
merged as `75a3e8c49be647ff663ea05207ed1badaa14db28`. Runs `35399491087` and
`35399933745` at that source/tree
`9724e3a2de1c31cfb4ca0fa3284aa423a8266b86` passed complete arm64 flows in jobs
`105775932697` and `105777334558`. X64 jobs `105775932698` and `105777334570`
passed the prior app's replacement/Quit and installed/launched the current app, but the
single inspector call 15 seconds after launch found no visible current window. PR #1542
added a bounded 45-second read-only window wait with per-attempt evidence and merged as
`305998d689d13051ac0fb58f9d970dfffe319bf0`. Main-only run `35405646668` then
accepted signed replacement with persisted Bridge Off intent on both CPUs, but did not
inspect live helper absence. The successor correction
`🌿 [desktop-distribution] Observe helper-Off during macOS replacement [step 8/14]`
merged in #1546 as `8d99cd2925c9866dc121323ed348b0d130bc6aca`. Main-only run
`35411687826`, tree `777f3a353ff04eaeab29f6a6ff3f81e514b04cf1`, passed tooling job
`105812432480`, x64 job `105812464127` and arm64 job `105812464132`. Artifacts
`10574093842` and `10574368671` record `NO_INSTALLED_HELPER` before both prior/current
Quit operations and every implemented `upgrade.json` check true. Private helper-Off is
accepted on both CPUs. PR #1547 recorded the boundary and merged as
`1ff3780b0b9244f5dada842c9e7735a28712fb2d`. The separate main-only authenticated
helper-On replacement probe merged in PR #1548 as
`cb23a7fc5d1f5b4fcedd1de2d591f88fd4074d43`. A dedicated `qa@sesori.com` production
account now exists, and its email/password are stored as repository Actions secrets.
The owner-requested `8.b/14` follow-up removed the obsolete environment binding and
merged as `8a22b16014966560f32819f1663ff6f81c9b4db8`. Merged-main run `35443816334`
measured source `8a22b16014966560f32819f1663ff6f81c9b4db8`, tree
`71c856139aadd86b88f0824d9cc838d885054023`, and passed tooling job `105899205055`,
but both serialized native jobs consumed their full 35-minute timeout in
the credential exercise immediately after prior-app installation (x64 `105899225214`,
arm64 `105899225125`). Bounded artifacts `10584848537`
(`sha256:cd20b47d9b0889a3e9ac1fe83a8f80741b4c287d5a91ad0f6c22dccd738bb0bd`) and
`10586555281`
(`sha256:b56678eb1c4938bedc90d6f95b1ed68aa53705ec8ba500c18c321e53fd3523c8`) contain no
Keychain/session/report success evidence, so the run is rejected. The `8.c/14` follow-up
atomically created the classic-Keychain ACL, bounded each native Keychain command, and
merged as `55547f26c8a9f59747987f1b7a65fc473e76e9c2`. Merged-main run `35454870471`,
tree `87fb1050b44566f9d456c21af16427823fbf60b2`, passed tooling job `105928266878`.
X64 job `105928289095` and arm64 job `105928289036` then failed within the bounded
prior-app helper wait rather than hanging; both observations record zero helper
processes and no authenticated/relay markers. Bounded artifacts `10587393605`
(`sha256:8d1d1f0af67d74bab0df5932aeb70b2d749c4bd5de6c24176fc017d1db184ca1`) and
`10588086362`
(`sha256:828eea306fec4d0e4d9a6942bddb462a2051fba5ca44bfa3956ec7786419fa5e`) contain no
session/report success evidence, so this run is also rejected. The concrete remaining
mismatch is that the writer's broad classic-Keychain insert did not carry the explicit
non-synchronizable (`kSecAttrSynchronizable: false`) and when-unlocked attributes
present in the pinned FlutterSecureStorage read query.
The `8.d/14` follow-up created and self-verified the item through that exact query
envelope and merged as `bf14d7c0f32def581febd1531214bbdd2be9fd74`. Merged-main run
`35460239311`, tree `ee65475efb25a2b0bad8121787fc5e38c37bc6d2`, passed tooling job
`105942674629`; reaching the helper wait proves the exact Keychain self-check passed.
X64 job `105942696871` and arm64 job `105942696897` nevertheless reached the same
bounded prior-app helper deadline with zero final helper processes. Bounded artifacts
`10588818277`
(`sha256:96e4895178bb2f98b7ea93a57dc05b5662727518fc0b8fc905981f275d83dd03`) and
`10589833036`
(`sha256:62159a3eefe8f3cec3bac361212de3ea8f294a6dc462ddbafdd241388ee9edd6`) contain no
session/report success evidence, so the run is rejected. The `8.e/14` follow-up records
only closed startup classifications from at most 1 MiB of phase-scoped private app
output, plus whether any helper generation or fresh bridge-log activity appeared. The
auth gate emits privacy-safe outcomes through the captured production log sink instead
of relying on `dart:developer`. It merged as source
`db9b0cd8bdf0e4b220d3f0fa069ec831e35f2a89`, tree
`20a3a04d3a3b5399f880cb46f79eb222e6e24f4f`. Merged-main run `35465783382` passed
tooling job `105957734614` but is rejected with conclusion `cancelled`. X64 job
`105957752803` stayed in the exercise step until its job deadline and produced no bounded
artifact. Arm64 job `105957752806` reached `previous: authenticated helper did not become
ready`; artifact `10591911157`
(`sha256:e4ee1899b990a5699e4127c86b83f9434a3e39ed90a808d3b6e308f734f03666`)
records zero helper processes, no helper/log activity and no startup marker while the
redirected output file is present. The `8.f/14` follow-up also scans the authoritative
private persisted `logs/app.log`, writes an atomic closed phase record, and gives the
exercise step a shorter deadline so always-upload can retain timeout evidence. Each
private source remains capped at 1 MiB; raw authenticated app/bridge output remains
private and is removed during cleanup. That follow-up merged as source
`e231295f8b00a8f7a7055e943cc6f4502dfda13c`, tree
`2d24d147f9f2be55e8885c4e81d3fbb7ecd17672`. Its merged-main retry `35496105360`
passed tooling job `106039227037` but was rejected on both native CPU jobs at the
previous-app helper-readiness deadline: x64 `106039268281`, arm64 `106039268268`.
Bounded x64
artifact `10601325063`
(`sha256:4ac6d8e635f46d6f8774ac385bebe3c5514225c38132034cd0328de7ce7bc386`) and arm64
artifact `10601410119`
(`sha256:431fea30cc86113f9d5fe388a76a625a58bfc011475f515d894f9096f949de7d`)
each record completed cleanup, zero helper processes, no helper/bridge-log activity, no
persisted app log, and a present non-truncated redirected app output with all classified
markers false. The `8.g/14` follow-up adds fixed privacy-safe markers before the production
log sink is installed, emits only a closed furthest startup stage from the same bounded
private sources, and separately records whether the downloaded package supports no,
pre-render-only or full pre-sink markers. Ordinary sources are inspected from the full Git
checkout; exact retained baseline `35042335424` uses its existing pinned metadata and
supports only
pre-render markers, so `noMarker` cannot claim failure before Dart main. #1564 merged as
`33a4ceb5506349d08953be37ba7d3a5f1d6d20df`, tree
`08f1d7b283faec4985a78b78ae8e7b7e4433dee9`. Fresh package run `35501361734` passed both
CPUs for `1.9.0+122`. Retry `35502787779` failed on both CPUs; each archive records
`previous` / `helperReadiness` and `preRender` / `desktopAttention`, with no helper activity
and completed cleanup. Replacement never began; the observed marker is not a proven
failing implementation. Prior run
`35496105360`'s two archives were mistakenly deleted; their recorded observations remain,
not retrievable archives.

The user resumed Step 8 with a local-first diagnosis requirement. Authorized disposable
modern-Keychain tests reproduced signing-partition denial despite the trusted-app ACL,
and a same-partition two-process control passed the pinned native plugin read. The
`8.h/14` correction signs the QA helper with the existing Developer ID, checks matching
helper/app teams, and uses that helper for private reads. No product startup change or
publication. Signing and QA secrets stay in separate steps; default/search-list settings
and existing local Keychains were unchanged during local tests. #1571 merged as
`fe5df8e9152688c76eab127eac6c615547effd29`, tree
`2549a8a964f534f462f5139d97aeaa15c925f73b`. Main-only authenticated run `35573213361`
passed tooling `106249150117`, x64 `106249218337` and arm64 `106249218239` using unchanged
package pair `35042335424` → `35501361734` (`1.8.4+24 → 1.9.0+122`). Verified archive
hashes and bounded reports establish all 15 checks, exact live authenticated helpers on
both launches per CPU, and completed cleanup. The fixture correction unblocked product
acceptance without a product rebuild or startup change. Full evidence is in
[step-06](steps/step-06.md). At the same merged tooling source, helper-Off run
`35575012582` passed tooling `106254787937`, x64 `106254857475` and arm64 `106254857531`;
all 11 checks and both live helper-absence markers per CPU were verified. Read-only
preparation `35575015316`, job `106254795658`, regenerated stable `1.9.0+122` metadata
and checksums for the unchanged package run. Its artifact hash and all four package
hashes were verified; no publication occurred. Ordinal `8.i/14` records these accepted
boundaries rather than reusing build-62 evidence.
Failed-stop, interactive user-account/TCC, minimum-OS, parent Gate C and public artifact
retrieval remain open; the download page itself is live.

Step 10 remains blocked until genuine platform releases and links exist. Step 11's
private-package documentation portion can proceed independently, so its dependency
is narrowed without reordering stable IDs or the 14-PR series. Its public-link and
onboarding closeout is assigned to step 10's existing ordinal 12/14 PR, together with
its genuine shipped-link changes; no second ordinal 13 PR is required. Step 11 is not
complete. Shipping order and uncompleted publication prerequisites are unchanged.

## Alignment — 2026-09-15

The user chose macOS-first delivery, Windows direct download, DEB/RPM for Linux,
installation on normal application quit for app-managed updates, all six native
OS/CPU targets, and GitHub installer downloads plus static GCS feeds/repositories.
The user subsequently authorized automatic implementation after the plan PR merges.
Start step 2 on the merge notification using `sesori-plan-worker`; thereafter keep
one series PR open and at most one successor step local. This supersedes the earlier
plan-only hold. Material scope/security decisions, missing credentials/infrastructure,
and the recorded public-release prerequisites remain gates; do not silently waive
or bypass them. Private signing qualification is underway; no infrastructure was
provisioned and no product was published. Private macOS test packages are now notarized.

Subsequent user clarification (2026-09-15): trusted, widely used, simple tooling
outranks automatic updates. A dedicated manual update button is acceptable.
Windows now uses signed Inno Setup installers and a Download update action, with
no embedded updater. The user explicitly accepts installer-only emulation on
Windows ARM64 and has no Windows ARM QA device. Installed application binaries
remain native; unavailable interactive QA is not passing evidence.

The parent [desktop-app tracker](../desktop-app/TRACKER.md) still records Gate C
and steps 21–22 as pending. This plan starts early at the user's request; those
statuses remain unchanged. Parent closeout is a first-public-release prerequisite
unless the user explicitly accepts a changed prerequisite. The merged
[desktop-ux plan](../../completed/desktop-ux/PLAN.md) redirects Gate C's shell/navigation checks
to its step-12 checklist; retain that incoming handoff and its separate ownership of
UI, autostart defaults and app logs. Distribution remains parallel, not a duplicate
UX implementation or a claim that its new checklist has passed.
UX retirement on 2026-09-19 explicitly accepts its remaining gaps; this plan's gates are unchanged.

## Unattended execution — user direction, 2026-09-15

Continue the entire implementation series without further questions. Never stop,
take over or replace the user's running bridge, including indirectly through the
active local desktop. The user selected fresh native CI for both Mac QA targets.
Run every safe autonomous check available; record checks requiring human input,
credentials, unavailable hosts or interactive permissions for the final handoff
instead of waiting. Deferred/blocked checks are not passes and do not authorize
public publication or silently waive the parent/release gates. Continue independent
implementation work when such a gate blocks execution; retain an honest final
verification handoff before deciding retirement/public release.

## Execution

Step 1 merged in [PR #1483](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1483)
as `ef6f3d6548`. Step 2 started automatically in the existing `tan-antelope`
worktree on branch `desktop-distribution-qualification`. Qualification does not
publish product releases or provision signing/hosting resources. Initial source/SDK
and signing-metadata evidence is recorded in [steps/step-02.md](steps/step-02.md).

Step 2 merged in [PR #1487](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1487)
as `833b989517`, with all six native build/inventory/relocated-helper E2E rows passing.
Step 3.a started automatically in the same worktree on
`desktop-distribution-bundle-identity`. The existing reviewed identity boundary is
unchanged; no new lifecycle owner, mutable state, database or wire contract was added.
Implementation, local native evidence and the approved architecture review are
recorded in [steps/step-03.md](steps/step-03.md). PR #1492 merged as
`575dd34dc322f88289efb68731482efe8885fa4b` after accepted head `1528c16f8` passed
24 checks. Final native run 34987193233 passed all six staging/inventory/relocated-
helper E2E rows at merge checkout `83e2e58b39732f706964f313ad13fa7d3f0f7f50`, with
empty canonical source diffs. Windows' stat-only Git false positive is corrected.
Step 3.b started in the same worktree on `desktop-distribution-repair-guidance`;
its focused implementation, approved architecture review and evidence live in
[steps/step-03b.md](steps/step-03b.md).
The existing service/state/presentation path retains user-facing repair guidance
before any installers. No public gate is waived by the split.

Step 3.b merged in [PR #1495](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1495)
as `e853838ac29b5d829f13622702c5d47a74eaa829`, accepting PR head `758bc554`.
Workflow 34994634843 passed its analyzer/test and three desktop build jobs at
Actions merge checkout `c40323edd60873d0a7d6f498ab05c4c8fd2b798f`. All review
threads were resolved; the final Cubic review approved with no findings.
Step 4.a merged in [PR #1499](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1499),
accepting `9f286805514a26cf5e641ab96ee16e79c3bcc7f5`, as squash
`cd4c1412359ef8962cb019d97dc7fed73835e1c8`. All 19 checks settled/passed at acceptance;
Cubic approved without findings. The later owner-controlled signing-secret migration
completed separately in #1525/#1527/#1531/#1532 and retired in #1534. Final unsigned
six-target qualification run 35036003267 measured merge checkout
`e4aa30f017cf876a1f61f2a6881f1282f013dba1`.
Steps 4.b, 5 and private step-6 preparation subsequently merged in PRs #1503,
#1506 and #1511. See the delivery records above for current work and exact revisions.
The following step-4.a evidence is historical; step-4.b evidence is recorded below.
Existing trusted CI credentials produce private Developer-ID-signed, notarized
and stapled packages on both native Macs. The reviewed manifest correction keeps
JSON in Resources and the complete helper in Helpers. Latest run 35019880379 at
`d5a03026dbfe7a95af0a262225c9f3ff640c74d1` qualifies 1.8.4/build 17: empty source
patches, matching downloaded hashes, seven-binary ZIP/DMG inventories, Gatekeeper,
helper E2E and signed synthetic Keychain/registration/file probes all pass.
Source/run/artifact attribution and approved manifest reviews are in
[steps/step-04.md](steps/step-04.md). No public package or local key export occurred.

Step 4.b fixes the separately demonstrated native-attention startup wait without
expanding package-signing ownership. At immutable implementation `25dc586`, all
32 attention cases and both strict client analyzers pass; scoped implementation
architecture review approved. Native package run `35038153010` measured that exact
source (**1.8.4/build 23**): both signed installed windows now visibly render the
login screen, and startup logs reach analytics/rendering. Both package/notary/helper
and synthetic platform legs pass; downloaded hashes and screenshots were inspected.
PR #1503 review exposed reachable pending-readiness logout and captured-retry gaps.
Follow-up `5b6bdb5` keeps readiness outside tracked native writes and replays startup
failure once: 36 attention + 17 logout cases and both strict analyzers pass; second
scoped architecture review approved. Signed run `35042335424` at `efefcbc` confirms
rendered login and package/helper/synthetic-platform checks on both CPUs (build 24).
Normal merge `eb54590` then preserved incoming desktop-UX popup/focus behavior;
37 attention + 17 logout cases and both strict analyzers pass on that merge. Native
artifacts remain attributed to `efefcbc`, not to the later integration commit.
Details and retrieval are in [step 4.b](steps/step-04b.md). The series has 14 PRs;
published history is preserved. No local desktop/bridge was disturbed. Real account,
notification authorization/delivery, interactive TCC, OS-login and ship gates stay open.

## Qualification and ship gates

| Gate | State | Evidence still required |
|---|---|---|
| Native build matrix | All six staging rows passed in final 3.a run 34987193233 | Signed/interactive release gates remain unverified. |
| macOS update | On/Off to build 122 accepted on both CPUs | Failed-stop, interactive, minimum-OS and public gates. |
| Windows update path | Simplified with user approval | Manual download + Inno Setup replacement; no WinSparkle/Velopack integration. Verify running-app refusal, safe Quit, signing and native application payloads. Installer-only ARM64 emulation is accepted. |
| Signing and static hosting | Migration complete | Public hosting gates pending. |
| macOS public gate | Pending | See checkpoint above. |
| Windows public gate | Pending; ARM64 interactive host unavailable | Both CPUs, per-user install/remove, actual signed manual N→N+1 upgrade, safe Quit, signing/SmartScreen observation and winget external path. Native CI build success alone does not close this gate. |
| Linux public gate | Pending; private mechanics passed on both CPUs | Public and interactive checks below. |
| Retirement | Blocked | Steps 10/11 closeout and the complete recorded matrix remain required. |

Linux public coverage still requires signed repository install/N→N+1 update/remove,
desktop-environment coverage, real account/keyring/tray/login behavior and declared
minimum OS. Retirement requires completed step 10 and the public portion of step 11,
then the complete recorded matrix. Partial, blocked or missing targets keep the plan active.

## Architecture plan review

Performed 2026-09-15 by the `medium-intelligence-fast` subagent using
`architecture-plan-review` (run `b982ac1f-8b95-4585-8912-20f6510f73d2`).

The initial draft was **rejected** for update policy in the cubit, ambiguous update
trigger ownership, unnamed DI phases, and unnamed bundle-manifest boundaries.
Historical automatic-updater architecture below is superseded by step 5's approved
manual fallback. It records the original review disposition, not current implementation
guidance: no update service, updater adapter, SwiftPM dependency or update lifecycle
subscription is now required. Step 5's explicit plan and implementation reviews own
the current architecture.

Applied the original actionable corrections directly:

- `DesktopUpdateService` owns preparation/state/handoff policy over the update
  repository. All update triggers flow through it. No second stop or restore owner.
- `BridgeControlCubit` retains serialized terminal sequencing and invokes the service
  only after `BridgeProcessService` successfully stops the helper.
- Shell updater adapter registers in phase 1; desktop API/repository/service in phase 4;
  the existing `BlocProvider` construction remains the cubit owner.
- Named `DesktopBundleIdentity`, its desktop-core model path, desktop build-time
  producer, manifest location, compiled identity, and pre-spawn resolver consumer.

No user decision changed and no additional mutable coordination was added. Per the
repository review rule, fixes were applied without re-review; do not describe the
corrected draft as reviewer-approved.

Step-2 qualification names the macOS adapter/SwiftPM dependency and replaces dummy
non-macOS updater adapters with a sealed platform capability selected in phase 1.
The user-approved Windows manual path has no updater lifecycle. These evidence-led
plan edits have not been presented as a new architecture-review approval.

PR review follow-up: explicitly named `main`'s guarded first-frame service startup,
subscription ordering, terminal cleanup, Injectable disposal, and cubit presentation
subscription cleanup. Kept the existing pure-Dart Layer-4 quit owner: all terminal
intents enter one tested method, while update policy remains in the service. A new
orchestrator solely for hypothetical future exit callers is not part of this plan.

## Planning validation

- Local Markdown links in all six changed/new documents: passed.
- All 14 tracker ordinals match PLAN.md: passed after the 4.a/4.b split. Published
  titles #1483/#1487/#1492/#1495/#1499 use total 14; commit history was not rewritten.
- Initial `git diff --check`: passed; final whitespace and diff size are checked again
  after review corrections, before committing/pushing.
- Initial measured diff: 555 additions + 17 deletions = 572 authored Markdown lines;
  no generated churn; final measurement belongs in the PR verification evidence.
- Architecture review completed and findings applied as recorded above.
- No Dart/Flutter suites were required for step 1's documentation-only PR.
