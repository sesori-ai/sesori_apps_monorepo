# Step 6 — Shared release cycle and desktop publication gate

Ordinal 8/14. Builds on merged step 5 (#1506). Private preparation is already merged.
The user selected the shared bridge/mobile release cycle on 2026-09-25. Continuation
`8.j/14` merged as #1724, wiring native macOS builds and gated asset attachment without
changing bridge/mobile finalizers or publishing a desktop release. Follow-up `8.k/14`
corrected the reusable callers' read-only PR-provenance permission in #1730. Acceptance
record `8.l/14` records the successful shared cycle and fresh stable-candidate replacement.
The user retired the remaining QA gate on 2026-09-26; continuation `8.m/14` merged
as #1761, admitting macOS and recording the first public internal assets. Website
continuation `8.n/14` merged in `sesori-ai/landingpage#111`; `8.o/14` records automatic
shared publication and live website verification without reopening the retired gate.

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
Core mobile/bridge success conditions, tags and attempt recording remain unchanged.
A desktop build failure stays visible without rolling back other products. Internal
rollover retains the newest desktop-completed public prerelease alongside the new core
release. Only older desktop previews retire, using the existing last-uploaded
`desktop-release.json` signal. No release service, extra pointer or build dependency
is added; transient shell values hold the public listing and retained tag. Stable
bridge/npm cleanup skips completed desktop previews; internal rollover remains their
retirement owner, independent of stable desktop availability.

`_reusable-desktop-publish.yml` runs only after native desktop success and the shared
release job. Production therefore already passed `store-production`; no second
approval is added. `DESKTOP_MACOS_PUBLICATION_ENABLED` defaults off for an unadmitted
platform; the user admitted macOS on 2026-09-26 and the variable is now `true`.
Internal and approved production cycles can attach desktop assets. Windows/Linux
publishing is not enabled.

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
migration plan retired in #1534. On 2026-09-26 the user directed **“retire this gate
and continue”** after the remaining QA was itemized. Gate C, minimum-OS execution,
remaining phone/live-harness cases and unversioned manual confirmation are accepted
limitations, not release prerequisites or manufactured passes. The configured macOS
12 minimum, existing 82-test shutdown evidence and source-specific build-981 acceptance
remain unchanged. No native fault injection or fresh build-987 authenticated upgrade
is claimed.

Remaining delivery work:

- Observe ordinary stable production when submitted through existing `store-production`.
  Normal internal shared-cycle attachment and the deployed website are verified below;
  no redundant store release is dispatched merely for desktop proof.
- Windows/Linux keep their independent signing/publication requirements. No additional
  publication credentials or hosted resources are provisioned here.

No automatic updater layers remain to clean up. The private producer stays separate
from public release authority. Windows/Linux publication remains disabled.

## First public macOS internal release (2026-09-26)

After explicit user admission, the existing publisher at main source
`60562904832dd54f3ad0f16b1871c860007e4aca` attached packages from successful shared run
[36198178787](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/36198178787)
to its existing
[v1.9.1-internal.987 release](https://github.com/sesori-ai/sesori_apps_monorepo/releases/tag/v1.9.1-internal.987).
Product/producer source: `acc0de273de4f9e618be7d2f362b1437b5d84541`; channel `internal`,
version/build `1.9.1+987`. The main-only producer succeeded before attachment.

This bootstrap invoked the unchanged publisher locally with completed-run provenance;
it did not rerun stores/builds, create/promote a release or pretend to be an in-progress
shared workflow. `DESKTOP_MACOS_PUBLICATION_ENABLED=true` admits future cycle attachment.
The publisher checked all downloaded payloads, refused overwrite and independently
retrieved every public asset without authorization before publishing the manifest last.

Verified public SHA256 values:

- arm64 DMG: `2b8af56e764796d7e8efbe65ffff180d97782b55303775c72e9108888938a633`
- arm64 ZIP: `337de503004a0e6563080313637d7357986790b2f3331e77e55aa9c37da700a0`
- x64 DMG: `e9e1c1ae49c53b1237046a3c893648ca0c4537e6fa09ec6bbf41a4fbe0e7412e`
- x64 ZIP: `5ab67e841c9f9b45a2347086730219fb5da6abb0af475867decbc94b3d98782a`
- `desktop-checksums.txt`: `ab783c78f2960937a51c7f984c3a1ac17a4a0b962f238dcea571129a127bc506`
- `desktop-release.json`: `1f82766e5f85ec3adfbef949c80554e895e42ef69721c4ba2fac759802b6ce8c`

The downloaded ZIP apps and DMGs passed independent strict signature checks against
Developer ID team `AQNCF7663C`, app/DMG stapled-ticket validation and app Gatekeeper
assessment for both CPUs. Assessment occurred without launching/installing either app;
it does not claim native x64 execution on the local ARM host or macOS 12 execution.
Public hashes matched those checked package bytes. No authenticated output was inspected.

Release `396977798` gained exactly the six expected desktop assets. Existing seven
bridge assets retained their IDs/sizes/digests; release identity/body/prerelease fields
and Latest stable `v1.9.0` (`395815709`) were unchanged. Private evidence stayed private.
This proves real internal publication and public trust, not stable promotion or
build-987 authenticated replacement. Build 987 also predates the subsequent desktop
shared-store cutover: its evidence does not prove new-format cold reopen, authorization
or N→N+1 preservation. Old-format internal users must sign out before replacing with
a shared-store preview and sign in again; this is not a production migration promise.
The rolling internal release can retire after a newer desktop-completed preview exists;
historical source/tag/evidence attribution remains explicit.

Review on #1761 identified that core rollover could delete the previous desktop assets
before a later desktop failure. The existing rollover now retains the newest completed
desktop preview without blocking core finalization. A second review identified stable
bridge/npm cleanup as another deletion path; it now leaves completed previews to the
internal rollover owner, even if stable desktop assets exist. Five offline tests execute
the actual cleanup shells through a fake GitHub boundary: repeated desktop failures,
advancement/older-preview retirement, pre-desktop cleanup, current-release retry and
stable cleanup with/without desktop assets. Three internal-rollover and both stable
cleanup subcases failed against their old implementations; all 17 publisher/workflow
tests and actionlint passed after correction. This is a local workflow regression proof,
not a forced live store/desktop failure.

## Automatic publication and deployed website (2026-09-26)

Admission/retention #1761 merged at `2026-09-26T08:28:17Z`, squash
`d72c9ae976a690569593eb925340d8d1e21c7d2b`; all 22 terminal checks passed. Its accepted
head was `e13b3f371b8c3f1703ca584afb9d82e2b7c360eb`, not the squash or later product source.

The ordinary shared run
[36230719108](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/36230719108)
succeeded from `2026-09-26T08:45:07Z` through `09:18:46Z`, with main product/producer
source `67bcc32ed3cdbdb00295c6572cd208cc78df6c68`. Mobile internal uploads, six bridge
targets, both native macOS packages, core finalization and automatic desktop attachment
completed for `v1.9.1-internal.991`. The run was observed after completion, not
redispatched for desktop proof. It proves the admitted shared-workflow attachment path;
the earlier completed-run bootstrap and scheduler no-ops did not prove that path.

[Website PR #111](https://github.com/sesori-ai/landingpage/pull/111) merged at
`2026-09-26T10:32:03Z`, accepted head `318336486370207dc12705d37fb3d1ed3cb32893`,
actual squash `d3ab0da1ac001c86e83089daf9a3937fc3c9ef6e`. The website selects the newest
completed shared publication independently per channel, requiring both native DMGs
with positive sizes/SHA-256 index digests plus desktop checksum and completion assets.
It follows release pages on the fixed repository endpoint within one five-second
budget. A five-minute cache coalesces success/failure lookups; failures remain logged.
The runtime trusts the publisher's last-uploaded marker, not per-request manifest
parsing or payload hashing. URLs derive from validated tags and expected filenames.

Review found the first-page-only stable discovery gap. A 100-entry/page-two regression
failed before the fix and passed afterward, also proving request coalescing and cache
reuse. The pinned `lru-cache` defined-result `forceFetch` respects TTL; it is not the
`forceRefresh` option. All **22 tests**, lint and real-SSR fixture contracts passed.
Merged-main CI
[36236080941](https://github.com/sesori-ai/landingpage/actions/runs/36236080941) passed.
Fixture screenshots use actual desktop widgets with demo data/fonts and explicitly
disclose native-control differences; they are not native AppKit or account QA.

The website automatically deploys its base branch after a push/merge, normally within
1–3 minutes. The initial immediate post-merge response still served the old page;
no dummy commit, GCP authentication or separate deployment was needed. Live headless
Chrome verification at **`2026-09-26T11:59:40Z`** checked `https://sesori.com/desktop/`:

- The preview CTA opens the internal macOS section. All eight channel/OS/CPU anchors
  plus `linux-package-managers` exist and select/reveal their correct sections.
- Exactly two internal macOS downloads are active. Stable and Windows links remain
  unavailable, Linux repositories remain unpublished, and stable structured data
  contains no version, offer or download/install URL borrowed from previews.
- Both production rows select **`v1.9.1-internal.993`**, not permanently pinned build
  987 or previously checked 991. Their anonymous HEADs return 200 and sizes match the
  GitHub asset index; displayed/index SHA-256 values agree with the public manifest
  and `desktop-checksums.txt`.
- Desktop `1280×900` and mobile `390×844` navigation run without browser exceptions;
  the mobile page has no horizontal overflow. Only an isolated headless browser was
  opened; the installed app, running Bridge and native user state were untouched.

Build 993's manifest identifies product source
`eb2bdb20070425fa163563b18177635a43656ab9` and successful ordinary producer
[36236723908](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/36236723908).
Checked live payload metadata:

- arm64 DMG: **44,585,961 bytes**;
  `4525499d5d1ae48754a1c54cd5717b31c856cbc9f2adcfcf74013ed58ef182b1`.
- x64 DMG: **45,237,370 bytes**;
  `11728112b58eb78c3f2e4696fb09d45fd95704c753a59f0d3f937fec3e73d473`.

These are deployed-page, anonymous-link and metadata-agreement checks, not new full-byte
hashing, Apple trust assessment, native installation or authenticated replacement of
builds 991/993. Build 981's old-format replacement evidence stays source/format-bound.
Stable production is not published; its existing approval and Windows/Linux gates
remain unchanged. Gate C and accepted macOS QA are not reopened.

Local bounded evidence under `build/landingpage-public-macos/`:
`shared-cycle-991.json`, `merged-pr-111.json`, `live-links.json`,
`production-verification.json`, `production-verification.log` and
`shared-cycle-36236723908.json`. The first link record measures 991; the production
record measures 993. Local files are ignored, not public release assets.

## Shared-cycle native evidence (2026-09-25)

Private package run
[36168531963](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/36168531963)
passed at workflow source `af23da2078a53f6515c75303f37b673e65983ec4`. Product source
`9ff459e6316ed91b285d573a03f15e0c598b24c3` is the main-ancestor target of existing
`v1.9.1-internal.981`; both new packages compile **stable `1.9.1+981`**. This tests an
older product source/shared build number without relabeling existing binaries.

Tooling job `108182131099`, arm64 `108182190901` (`xcode-27`) and x64
`108182190956` (`macos-26-intel`) passed. Each native job staged clean source,
signed/notarized packages, exercised the extracted helper with isolated fakes and
probed the installed GUI/separate platform fixture. Both ZIP/DMG inventories contain
the same eight native binaries; both app and DMG receipts report `Accepted`.

| CPU | Private packages artifact | Evidence artifact / verified archive SHA256 |
|---|---|---|
| arm64 | `10879113046` | `10879322858` / `0d605543f6466fbbe575e6f67c4c0f8c2a6c9d5353a9aa9da58c8f1b1a3fcb2a` |
| x64 | `10881365014` | `10880830350` / `b080fee29a4520460278d89529283ec57edd7b137b1a54a247b70608a116321b` |

Read-only preparation
[36171714173](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/36171714173)
passed job `108192600638` at tooling `9e2adab90b47c1f3607a02414c978bd9abe6f050`.
It downloaded and hashed all four payloads; independently inspected evidence archives
and preparation metadata agree on identities, stable channel, clean patches, receipts,
inventories and these payload SHA256 values:

- arm64 DMG: `3664b979dd9418696c2fef6cef4dd409a07642b1f4f45dcf206894044aaaf9d7`
- arm64 ZIP: `6562da55ebc412e4a562c8fa0da9f0d4fa5492594f2dfdd74d3fbcd15ee8bbd3`
- x64 DMG: `695a5b3d6f0a8dee2787bab151f75a88d1c3afc0329df0dc8f0eaeddd9d66dc3`
- x64 ZIP: `b3a8949f9b6fd49e613a0c263ab3944b53756c8b3099a766b66033cf4c8117cc`

Preparation artifact `10880996051` has verified archive SHA256
`e4f642973fcb4073600cf45a246691a392658d66522e51b9383e006023336325`.
It proposes shared tag `v1.9.1` but does not publish it. Subsequent authenticated and
Bridge-Off acceptance for these same packages is recorded below; minimum-OS/interactive
acceptance and public trust remain open. The local installed app/bridge was untouched.

Scheduled shared run
[36169071807](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/36169071807)
was rejected at startup: the nested `macos-upgrade` and `macos-authenticated-upgrade`
jobs request `pull-requests: read`, even though packaging would skip them. No job,
release-attempt write, store query or upload ran. The `8.k/14` fix grants that read-only
scope to the internal and production native-desktop callers; it does not broaden
publication authority. Private package acceptance above does not accept this failed
shared run. PR #1730 merged the correction as `8d0680736389afe8cad6cc9008fbbd512f96b9d0`;
18 checks passed at acceptance and Codex completed without findings. The merge report
had an additional nineteenth check running; it is not included in that acceptance count.

At correction commit `99c95999e101d6524ea8b7b3f248876088ac9f95`, branch-only validation
[36172912862](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/36172912862)
passed GitHub's workflow admission, then intentionally failed the existing main-only
guard. Only preflight job `108196547789` ran; checkout, attempt recording, version
validation and all seven other jobs were skipped. Watch exit 1 is expected here,
not a successful release. Both caller-contract subcases failed before the permission
fix; all 12 publisher/workflow tests and actionlint passed afterward.

## Candidate 981 replacement acceptance (2026-09-25)

The unchanged stable pair `35042335424 → 36168531963` passed on both native CPUs:
`1.8.4+24 → 1.9.1+981`, with current product source
`9ff459e6316ed91b285d573a03f15e0c598b24c3` and the DMG hashes above.

| Probe | Run | Tooling source | x64 job | arm64 job |
|---|---|---|---|---|
| Authenticated On | `36174286284` | `8d0680736389afe8cad6cc9008fbbd512f96b9d0` | `108201087316` | `108201087442` |
| Credential-free Off | `36175102660` | `f518cf28b465b16dd91baad74d45cbe16f647403` | `108203736502` | `108203736443` |

Authenticated reports have all **15/15 checks true** per CPU. All four prior/current
launch observations contain exactly one live helper, observed during the wait, with
fresh activity, authenticated profile and relay-serving readiness. Both final records
are `complete` with cleanup started/completed. Real tray Quit stopped the observed
helper without relaunch/orphan; Keychain, On intent and bounded preservation checks pass.

Credential-free Off reports have **11/11 checks true** per CPU, including live
`helperAbsentBeforeQuit`. All four inspected prior/current helper-off records are
exactly `NO_INSTALLED_HELPER`. Both candidate identities/admission records and DMG hashes
match the authenticated reports. This is not authenticated-Off or arbitrary-history
coverage. Tooling jobs `108201016969` (On) and `108203675495` (Off) also passed.

Verified evidence artifacts and archive SHA256 values:

- Authenticated arm64 `10882280757`:
  `afe95ee11a96ea5a427dd9e4e2d477ba6f955eb3886635948ac364d4517b0d19`
- Authenticated x64 `10880254809`:
  `46a23896d0f8ed0f3a9b104addb520524e44fbceee8710545c8c76afacc04dc7`
- Off arm64 `10882555640`:
  `2eb201a94a39c6592b8bf10b129e2b4bd5558e6a75a857df6ed34042320264d1`
- Off x64 `10882356250`:
  `f6a1cfc39dc3bbf3ac10deac4dd9279b15fcfcf770c9d19ce425c0ad6a3e7742`

Only allowlisted bounded JSON and exact Off absence records were inspected; no raw
credential/auth response, authenticated app/bridge output or screenshots were read.
The local app/bridge was untouched. These runs do not close interactive login/TCC,
physical-phone, minimum-OS, failed-stop injection or public-release gates.

## Successful shared internal cycle (2026-09-25)

Normal scheduled run
[36175398399](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/36175398399)
passed from `f518cf28b465b16dd91baad74d45cbe16f647403` after the permission correction.
This was the existing scheduler, not a manually dispatched product release. Preflight,
aligned numbering, Android internal upload (`108205442335`), TestFlight upload
(`108205442354`), all six bridge builds and core finalization (`108209549733`) succeeded.
Both desktop jobs passed (`108205508675` x64, `108205508677` arm64; tooling
`108205442972`) with **internal `1.9.1+983`**, the same source/build as the shared cycle.

Desktop publisher `108216849107` was skipped. At verification, the rolling prerelease
`v1.9.1-internal.983` resolved to that exact source and contained only six bridge
archives plus `checksums.txt`, with no desktop assets. Desktop admission remains off.
Native desktop evidence has empty source patches, matching compiled internal identity,
equal ZIP/DMG inventories of eight native binaries and accepted app/DMG notarizations.

- arm64 evidence `10882692646`, archive SHA256
  `55a364b785c1fef80ee00ba777bff558e8e045e5760588b505fba048a71b2f85`
- x64 evidence `10883178203`, archive SHA256
  `795d64225dfe48adb10eea5435f19a29f19387fb52f93fedf2b6be3403122bc7`

Read-only preparation
[36179427817](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/36179427817)
passed at `fd2aa0fbb23ebfe578dcfc06704691082c7a82f6`, job `108217896893`.
Its artifact `10884050786` has verified archive SHA256
`d59684b6cf7f955b6e0872b616dcd5d66d5dbb97777077ae9a22b764e863ee12`.
The real shared-run producer, source/build/channel, proposed internal tag and downloaded
payload hashes passed the consumer, independently matching the inspected native records:

- arm64 DMG: `cd3f3eb1a034929924b0bfab5a01c96e7acf154bbd6abb6a115602b71b59191e`
- arm64 ZIP: `1fb47e248a0683b01b0dfa29e0c8f27523871f0774265fb7ff3c2222e8c18133`
- x64 DMG: `8471a1d4dd06b72c269e0660fe228e4f67b1d91f3b638c9bb2e63a883ef16554`
- x64 ZIP: `94721edbb8dd626345b7f159cc3386686ab7ba63ae8e2eba3e9240bb5d1c4ff6`

This proves the shared internal build/finalization path with desktop publication off,
not the disabled public publisher, stable production attachment or build-983 authenticated
replacement. Build 981's stable acceptance above remains a separate source/build/channel.

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
