# Step 9 — Linux packages, signed repositories and publication

Ordinal 11/14. Linux remains ahead of Windows (D10/D13). CLI signatures, public
internal previews and their website discovery are complete. On 2026-10-14 the user
approved public GCS package hosting/scoped GitHub publishing IAM in `sesori-ai`, then
requested finishing Linux including stable publication. That direction authorizes the
remaining implementation/publication work, not a waiver of repository trust, native
GUI/account/keyring/tray or genuine upgrade qualification. Preserve ordinary production
approvals and the existing release cycle. Windows and new release backends stay separate.

## Repository continuation — 11.g/14

`build_linux_repository.py` consumes the existing prepared desktop release. It checks
both CPUs/formats, package hashes and signed checksum inventories against the known
primary key, then checks DEB/RPM headers and native RPM signatures. It preserves
package bytes and delegates index generation to `apt-ftparchive` and `createrepo_c`.
The existing temporary signing owner signs APT `Release`/`InRelease` and each RPM
`repomd.xml`, verifies with public material and cleans private state before recording
completion. Tools install before secrets; tests use disposable keys only.

APT suites/pools and RPM CPU roots separate `internal` and `stable`; tooling support
for both channels does not admit stable product publication. APT metadata expires
30 days after generation. Protected repository signing and weekly metadata-only
refresh of accepted packages belong to the 11.h workflow below. APT indexes include
SHA-256 by-hash objects; RPM indexes use checksum filenames. The publisher continuation
must retain old referenced content and upload payloads/indexes before signed entrypoints.
No GCS resources, IAM, public repository or release changes are made by this builder.

Real-tool fixtures cover signed indexes, both architecture headers, unchanged package
bytes, channel/signer/input refusal and isolated APT/DNF install/upgrade/remove with
inert payloads. This is repository mechanics, not native application upgrade or account
proof. Next slices are hosting/publication (11.h), native desktop qualification (11.i),
website discovery/instructions (11.j), and qualified stable publication (11.k), as
specified in [the plan](../PLAN.md). No new application state or updater is introduced.
Existing manual preview downloads remain supported; no application mechanism becomes
obsolete. Repository-only dependencies extend the signer in a separate image rather
than burdening ordinary package/CLI signing. Stale hosting/stable-scope wording is
replaced by D13, not retained as a contradictory gate.

## Preview repository hosting — 11.h/14

`linux-repository.yml` follows completed public preview publication and provides weekly
metadata refresh/manual repair without app or store builds. Signing and bucket-scoped
Google publication run in separate jobs. Independent verification authenticates the
complete signed reference tree; immutable conflicts, expired metadata and downgrades
refuse publication. Content-addressed files precede signed entrypoints, with InRelease
last. The CI inventory is not a new public release pointer.

The approved `sesori-ai-linux-packages` bucket and dedicated federation/service account
are provisioned. The user additionally authorized a bucket-tag-scoped exception to the
observed domain-sharing block, preserving the previous restriction elsewhere. Anonymous
repository delivery passed in main run `38754986125`: production signing, scoped
federation, pinned public signatures/references and real HTTPS APT/DNF refresh/download
for both architectures. Clients ran in an ARM64 Fedora container; no application was
executed. [Retained summaries](https://github.com/sesori-ai/sesori_apps_monorepo/pull/2002#issuecomment-6196620863).
Operational ownership and repair: [Linux repositories](../../../../docs/desktop/linux-repositories.md).

## Native tray correction and qualification — 11.i/14

Native KDE run `38769349531` reached the real anonymous window and close-to-tray path,
then found `/NO_DBUSMENU`. The adapter leaves the native context-menu trigger unset;
Linux consequently exports no usable menu, and manual `OpenContextMenu` is unsupported.
11.i.a/#2004 sets the Linux trigger before publishing the menu/icon. No new state, lifecycle
owner, persistence or macOS/Windows behavior is added.

On 2026-10-15 the user approved landing this focused fix with tests, then obtaining
native visual and upgrade proof from fresh signed builds. #2002 delivered 11.i.b;
its old `1021/1022` package bytes cannot be repaired in place or used to claim the fix.
The user then approved two separately compiled signed versions of the corrected source
`0e076d27cb928e3ee802d6e650efc4097ba5fb55`, selected through producers `38774801356`
and `38791726962`. Strict package-version increase remains required; this is not a
code/schema migration claim. The report records whether product source changed.

The native gate covers credential-free x64 GNOME/Wayland and ARM64 KDE/X11, encrypted
fixture persistence and login-registration roundtrip. KDE uses the owned Plasma
accessibility targets for real pointer clicks, captures the visible menu and clicks
Quit; it does not substitute direct DBusMenu event dispatch for host interaction.
Final [run `39122836416`][native-run] passed both CPUs at qualification checkout
`5a75d4b3c01de0f1a3139bb9e0f864d1296cfe48`, from repository-root `$GITHUB_WORKSPACE`.
Jobs: [x64 GNOME/Wayland `117662042263`][native-x64] and
[ARM64 KDE/X11 `117662042236`][native-arm64]; #2002 merged.

[native-run]: https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/39122836416
[native-x64]: https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/39122836416/job/117662042263
[native-arm64]: https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/39122836416/job/117662042236

All four anonymous windows and both genuine KDE menus were inspected. Original signed
167→168 bytes passed normal Quit/no orphan helper, real Secret Service/encrypted SQLite
continuity, login-registration roundtrip and package cleanup. KDE's pre-existing
tray-disposed diagnostic remains recorded, not a warning-free quality claim.
Private `linux-interactive-debug` and #2019's canonical skill/Claude shim are delivered;
scoped OIDC, admin SSH and loopback VNC remain credential-free and never waive acceptance.

11.i.c.a adds main-only authenticated replacement using `qa@sesori.com`, credentials
only in the exercise step and one serialized account/relay slot across Linux and macOS.
The current qualification checkout supplies one nonshipping typed auth/persistence
fixture, compiled separately against each candidate's locked product source/APIs;
it does not use a historical fixture from each producer. Login seeds only the old
package; the newer signed GUI opens preserved data before its fixture can change intent.
Exercise previous On→Off, replace, then current Off→On, normal GNOME close and native
KDE tray Quit.
Authenticated pixels and raw app/bridge/auth output are not uploaded. Linux uses real
GNOME Keyring in native x64 GNOME/Wayland and ARM64 KDE/X11 sessions. Tooling/mocked
contracts do not establish acceptance; dispatch both CPUs from merged main.
11.i.c.b retains actual OS-login, unavailable Secret Service, remaining nominated
native distros and source/schema migration gates. Same-source inputs cannot prove the
last gate; no host, signing-policy, publication or installed-Mac change is authorized
merely by this tooling. Stable stays closed.
Keep the existing release rollover: QA uses retained signed producer artifacts, not
historical release objects that can disappear. No hidden-menu bypass, force-Quit pass,
recreated release or silent same-version substitution.

## Signing continuation — 11.a/14 (merged)

PR title: `🚧 [desktop-distribution] Sign private native Linux packages [step 11.a/14]`.

- Keep unsigned DEB/RPM construction and its evidence intact. A new small post-build
  signer verifies their hashes and matching identity, copies them to a fresh output,
  signs the RPM natively, then signs SHA-256 checksums covering both final artifacts.
  DEB bytes remain unchanged; detached checksums are not native APT repository trust.
- Only main may run credential-bearing `linux-packaging`. The `linux-signing`
  environment allows main only and stores a protected secret-subkey export and
  passphrase; its public variable pins the full primary fingerprint. The primary
  certification key and revocation certificate stay with the user, offline.
- Build signing tools from the existing pinned Fedora image before supplying secrets.
  Sign in a network-disabled container; import into a temporary private GnuPG home,
  remove secrets from child environments, verify with public material and clean up
  the agent/key files. Upload only signed packages, public key/checksums/signature
  and separate public provenance, never the keyring or passphrase.
- Existing native Ubuntu/Debian/Fedora install/reinstall/remove fixtures consume the
  signed output, verify checksums first and require native RPM signature verification.
  They still do not launch the GUI/helper or establish a real N→N+1 update.
- Local unit/source contracts and actionlint/ShellCheck cover boundaries. PR CI uses
  a disposable certification key plus signing-only export to exercise real GPG/RPM
  signatures, wrong key/passphrase refusal, tampering and isolated DNF signed-package
  install/reinstall/remove versus unsigned refusal. The fixtures never receive
  production keys. Actual signed x64/arm64 qualification runs only after merge.

Complexity: approximately 700–1,000 authored lines, no generated/application changes.
Only temporary signing files and a public report are added; no service, updater,
coordination state, cloud provisioning or publication authority. Native payloads
stay unchanged. Remove unsigned-only uploads/fixture assumptions that this replaces;
retain unsigned source reports as input provenance. Key setup and backup instructions:
[Linux package signing](../../../../docs/desktop/linux-signing.md).

## Accepted signed native qualification — 11.b/14

#1941 accepted head `5eb40f89a7e76902328431912032b0d5a3bf7ace` merged as
`de53cafb2483d76e9350a28d014b4d3906ee0fe0` on 2026-10-13. Final PR CI passed;
its pinned-Fedora suite ran all 12 tests without skips, including protected-subkey
GPG/RPM/GPGV verification, tamper refusal and isolated DNF signed acceptance/unsigned
refusal. Cubic approved the final head; Codex completed without findings shown.

Main-only [run 38372268594](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/38372268594)
then succeeded at that exact merged source, producing private `1.9.1+147` packages.
Tooling job `115211910113`, native x64 job `115212528442` and native arm64 job
`115212528505` all passed. Both CPUs used the configured `linux-signing` environment
and full primary fingerprint `E6BF6EF7B203685F480D4A2E73B86E42F31FDAE7`.
Committed source tree: `d55bf537542f9650b6633ae9bba0d02eaa840c0e`.
Both checkout logs explicitly report cwd
`/home/runner/work/sesori_apps_monorepo/sesori_apps_monorepo`.
The workflow is `.github/workflows/desktop-qualification.yml` at the exact merged
source above; use that immutable revision, not today's `main`:

```bash
source=de53cafb2483d76e9350a28d014b4d3906ee0fe0
git show "$source:.github/workflows/desktop-qualification.yml"
gh run view 38372268594 --repo sesori-ai/sesori_apps_monorepo \
  --job 115212528442 --log
gh run view 38372268594 --repo sesori-ai/sesori_apps_monorepo \
  --job 115212528505 --log
```

Direct execution logs:
[x64](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/38372268594/job/115212528442),
[arm64](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/38372268594/job/115212528505).
These identify the executed commands; rolling dependency repositories still prevent
promising byte-identical future rebuilds.

All six Ubuntu 24.04, Debian 13 and Fedora 44 fixtures verified signed checksums,
complete root-owned installed payloads, bounded package ownership, same-version
reinstall, removal and shared-data sentinel preservation. Fedora required native RPM signatures.
These fixtures never launch the application or helper.

Independent verification downloaded the four artifact archives, matched their GitHub
SHA-256 digests, confirmed matching source/build/CPU identities and empty source
patches, compared installed/reinstalled records, and verified detached checksum
signatures against the separately known public fingerprint. No private key was read.
Final package-file SHA-256 values:

| CPU | Format | SHA-256 |
|---|---|---|
| x64 | DEB | `57dfbd50ec8e31445cb0326b52729755c76903289b4f02b1887a41d32769bffc` |
| x64 | RPM | `ceeebe8e05bb376a88b16ec635249a53e147901d089562af90bc32c183ee73ee` |
| arm64 | DEB | `80b962888f376ef8700a550198e0a90fdc2683270f11c4f3ffe3b99a01b33e32` |
| arm64 | RPM | `3c75897a1a7ac25b5b7be174e14ae038af174f268a887b1738f6b353c4f18ed9` |

Private artifact IDs: packages x64 `11799393614`, packages arm64 `11800321120`,
evidence x64 `11800500056`, evidence arm64 `11799284588`. Retention remains 14 days;
these are not permanent public download links. Local acceptance summary:
`build/desktop-linux-signing/native-38372268594/verified-summary.json`.

Build 147 belongs to this manual qualification workflow, not the shared release
sequence. Public integration must supply aligned source/build/channel and retain its
validation metadata. Public signed APT/RPM repositories, shared-cycle publication,
real N→N+1 updates and GUI/account/keyring/tray/login/desktop-session qualification
remain separate. No cloud resource, public release/repository or store upload was
created, and no local GUI/helper was installed or launched.

## Public CLI signatures — 11.c/14

#1946 merged as `a3457903cf50155345e7afd293e7ec564d0e3238` on 2026-10-13,
accepting `e727acb68d85bc0998c5f7d703d61ca78dbfc865`. All 41 pre-merge checks passed
or intentionally skipped; Cubic approved, Codex completed and seven threads were resolved.

Protected [run 38412243041](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/38412243041)
succeeded for existing public CLI release `v1.9.0` (release ID `395815709`). Its workflow
source is the squash above, tree `9aa6295e7f194667d9fb3f3b34c34606f81ec028`.
Both checkout logs report `/home/runner/work/sesori_apps_monorepo/sesori_apps_monorepo`.
Signing job `115347301887` uses the network-disabled container; publication job
`115347682039` adds only missing public signing assets. Exact executed definitions/logs:

```bash
source=a3457903cf50155345e7afd293e7ec564d0e3238
git show "$source:.github/workflows/sign-linux-release.yml"
git show "$source:.github/workflows/_reusable-linux-cli-signing.yml"
gh run view 38412243041 --repo sesori-ai/sesori_apps_monorepo --job 115347301887 --log
gh run view 38412243041 --repo sesori-ai/sesori_apps_monorepo --job 115347682039 --log
```

Independent anonymous retrieval compared archive/checksum bytes before and after,
matched public index SHA-256/size, and verified both detached signatures with GPGV 2.5.24
using only the independently known primary fingerprint
`E6BF6EF7B203685F480D4A2E73B86E42F31FDAE7`. Both signatures identify signing subkey
`2BB08B81FF5491A1F68C95C7CBACDB2E5623160F`. All seven original asset IDs/sizes/digests,
release metadata, annotated tag object `5f031b47b5fb99bf533dc77a9c707098d0a5a73c`,
and Latest `v1.9.0` stayed unchanged. Downloaded files:

| File | Bytes | SHA-256 |
|---|---:|---|
| `checksums.txt` | 586 | `27f8e370977eca565b2b46f714e2cf1e756ed9d1f6ce5715b1f43e13176d5585` |
| `sesori-bridge-linux-x64.tar.gz` | 8472547 | `8758948aed48395ace75a0c957bea637d9e8c7627544c6780f48400be868fb5d` |
| `sesori-bridge-linux-arm64.tar.gz` | 8271769 | `edb6effc82bd08833777efc602e365eff6254c59b920c9994f4fc217d71b33ff` |
| `sesori-bridge-linux-x64.tar.gz.asc` | 833 | `df799c125930e84fbd14d3eef88fe73b775906fce91635c82b6942297bc123ee` |
| `sesori-bridge-linux-arm64.tar.gz.asc` | 833 | `fa63837b7f5a6b3869de1593a2191e5c042eadf20b00b99e74141e5fde1142bb` |
| `sesori-linux-public.asc` | 4008 | `44c84486c75d5a404cdc3b53cebc911f3dddc64bea7cd0ad0abe2bffc3ef45f7` |

Local evidence: `build/bridge-linux-signing/public-v1.9.0/verified-summary.json`,
public-only verification logs, before/after metadata and downloaded bytes. The first
local import hit macOS's agent socket-path limit in a nested tool temporary directory;
a short owned GnuPG home fixed that probe without re-signing or changing public assets.
No archive was rebuilt, unpacked or executed; no store, desktop or repository publication
occurred. These are CLI signatures; installers/updaters still enforce SHA-256, not OpenPGP.

## Aligned desktop internal previews — 11.d/14

The approved continuation reuses native Linux qualification with the shared product
source/build/channel and retained `dart-defines.env`. Product SDK/icon/plugin inputs
stay source-specific; signing/fixture tooling comes from the trusted workflow revision.
Linux/macOS calls do not cancel each other. Core release prerequisites remain unchanged.

`desktop-linux-release.yml` attaches only to an existing public internal tag resolving
to the package source. It checks both CPU identities, signatures, hashes and six native
fixture reports, preserves each signed checksum pair, and publishes a Linux-specific
completion marker last. The desktop key has its own immutable filename, not the CLI
owner's replaceable key asset. Rollover retains the newest completed release per platform.
No new service, admission flag, application state, production approval or updater exists.

#1951 accepted `fc536a9ceca952466372cb8e03ee16f98773a1b8`, tree
`75e067bff95bb97eb6a2b54d0ddd2d4d44794aa9`, and merged as
`69b3c4a329bb52f51fe5b07da9801346928268e2` at 2026-10-13T17:22:18Z. Five review
threads were resolved and Cubic approved. Intel job `115401956425` exceeded its unchanged
40-minute deadline; its logs were unavailable. A single failed-job-only retry in run
`38427767587` passed. This is retry success, not a diagnosed root cause for the timeout.

### Public native desktop verification — 11.d/14

On 2026-10-13, both native CPU packages were built for the existing shared public
`v1.9.1-internal.1013` release (`405100008`), not relabeled from private build 147.

| Role | Commit | Tree |
|---|---|---|
| Product | `704c3cae3c0f74c7756fcbf8cb2f60f1cebbb6b2` | `f8c697207ca00eb0278961a6fca1b92335628c74` |
| Native/local | `69b3c4a329bb52f51fe5b07da9801346928268e2` | `adec647ee87059c7efba7e2f8f5f292b4c538f90` |
| Publication workflow | `5dfef8672ffefdf1ce94a0f69596f195bf0874ad` | `2dea21dae00a7a2fe4db87aee74c18bad486facc` |

[Native run 38438783418](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/38438783418)
used main-only `linux-packaging`, selected the product's pinned Flutter 3.47.5 SDK, and
retained exact compiled `internal` / `1.9.1+1013` identity. ARM64 job `115439936920`
and x64 job `115439937034` passed all six Ubuntu 24.04/Debian 13/Fedora 44 fixtures.
The four Actions ZIP hashes/sizes, clean source patches, signed/unsigned package provenance,
unchanged DEB bytes, source identities and both actual GPGV signatures passed local checks.

[Publisher run 38443588001](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/38443588001),
job `115456112776`, reused those original artifacts, finishing at 18:03:32 UTC.
Executed dispatches, with the workflow revisions attributed above:

```bash
gh workflow run desktop-qualification.yml --repo sesori-ai/sesori_apps_monorepo \
  --ref main -f mode=linux-packaging -f channel=internal \
  -f source_sha=704c3cae3c0f74c7756fcbf8cb2f60f1cebbb6b2 -f build_number=1013
gh workflow run desktop-linux-release.yml --repo sesori-ai/sesori_apps_monorepo \
  --ref main -f packaging_run=38438783418 \
  -f source_sha=704c3cae3c0f74c7756fcbf8cb2f60f1cebbb6b2 -f version=1.9.1 -f build_number=1013
```

These are historical dispatches, not instructions to generate fresh signatures for a retry.
Both native checkout logs explicitly report the product checkout at
`/home/runner/work/sesori_apps_monorepo/sesori_apps_monorepo` and the trusted workflow
checkout at `/home/runner/work/sesori_apps_monorepo/sesori_apps_monorepo/.ci-workflow`.
The fixture Docker commands mount that same absolute workspace and use
`-w "$GITHUB_WORKSPACE"`; they invoke the qualifier from `.ci-workflow`, not an unpinned
copy from today's main. Inspect the immutable workflow/qualifier and expanded execution logs:

```bash
workflow=69b3c4a329bb52f51fe5b07da9801346928268e2
git show "$workflow:.github/workflows/desktop-qualification.yml"
git show "$workflow:.github/scripts/qualify_desktop_linux_package.sh"
gh run view 38438783418 --repo sesori-ai/sesori_apps_monorepo \
  --job 115439936920 --log
gh run view 38438783418 --repo sesori-ai/sesori_apps_monorepo \
  --job 115439937034 --log
```

These logs identify each CPU's fixture invocation, package/bundle path selection and
container image digests. Local copies are `native-job-<job-id>.log` beside the evidence below.
Local verification ran from this checkout's root (`.`), with Python 3.13 and a short,
public-only GPG home. It independently downloaded
all ten new public files without authentication and verified both signed checksum pairs
against primary `E6BF6EF7B203685F480D4A2E73B86E42F31FDAE7`, signing subkey
`2BB08B81FF5491A1F68C95C7CBACDB2E5623160F`, then checked all four package digests.

| Package | Bytes | SHA-256 |
|---|---:|---|
| ARM64 DEB | 20822010 | `984d7e2ec9db091624afa977970a7e23aa1ffa89dd0818e6293c90905157aa19` |
| ARM64 RPM | 20758451 | `764029166b7cea1fcab5aace6fdcb64d95d5d1b8537ab8d2de4ff35e3d4f9bab` |
| x64 DEB | 21311998 | `af9ff52a9888e754e6169be99fe41a9493a5725bf6c3cbb605383405ed21c720` |
| x64 RPM | 21262293 | `bad6787061d80bac151653d3846afd8939383691d5f701a2dc2c02c0b9012319` |

The original 13 core/macOS assets kept their IDs, sizes and digests. Release identity,
content, channel, target, tag and Latest (`v1.9.0`) stayed unchanged. Outside the asset
list, only GitHub's automatic `updated_at` changed. Original `checksums.txt`,
`desktop-checksums.txt` and `desktop-release.json` bytes were re-downloaded and compared;
this is not a claim that all original archives were re-downloaded. No release was created,
no store upload or local application/package installation ran, and no repository/cloud
resources were provisioned. Completion is public package/signature delivery only.

Local records: `build/desktop-linux-publication/public-1013/verified-summary.json`,
`native-downloads-verified.json`, `prepared-local/desktop-linux-release.json`, run/job
records and `verify-public.py` in the same directory. GUI/login/keyring/tray and real
N→N+1 remain unverified and accepted only for internal previews. Stable Linux and
APT/RPM hosting remain unadmitted.

## Live website acceptance — 11.e/14

`sesori-ai/landingpage#112` accepted `3fbc80d42d069905655a33fe47616d2b649b65de`,
then squash-merged as `77772b9d2c7ce083183ff275b37d8f864cf1e237` at
2026-10-13T19:15:34Z. Both revisions have tree `6247f8d552ce73b33455be0c8ecf4619b69fad91`.
The 649-line/12-file change extends the existing anonymous cached release lookup with
independent Linux completion, four per-format download rows, explicit preview limits,
verification links and spacing below the preview actions. It preserves every shipped
app fragment and does not turn preview availability into stable/repository availability.

Node 22.23.2/npm 11.19.0 completed 26 tests without skips, strict focused TypeScript,
ESLint and real SSR contracts at the implementation checkpoint. Synthetic font-loaded
browser fixtures covered both platforms, Linux-only, stable macOS with Linux previews,
and unavailable states. Cubic's one finding identified duplicated stale crawler FAQ
copy; the follow-up corrected it and added an assertion scoped to that answer. The new
assertion rejected the old copy; SSR, focused lint and formatting passed after the fix.
Final-head Site contracts passed. Cubic reported all findings addressed; Codex's quota
notice supplied no code review. No production resolver/UI change followed the fixtures.

Normal website deployment was independently checked at **2026-10-13T19:20:22.227Z**:

- `https://sesori.com/desktop/` served all four real Linux `1.9.1+1013` package links;
  macOS independently selected the same internal tag. Each Linux URL returned anonymous
  HTTP 200 with the correct package size. Displayed hashes matched the release index,
  public manifest and per-CPU checksum list. All verification-file bytes matched their
  published digests; packages were HEAD-checked, not rehashed in this browser pass.
- Desktop 1280×900 and mobile 390×844 both measured **32px** below the preview group,
  versus the fixture baseline's 0px. Fonts were loaded; no horizontal overflow or
  browser exception occurred. Preview navigation opened its channel; the shared
  experimental-warning link landed below the sticky header.
- All 13 download/app anchors worked. Stable desktop schema remained without download,
  version, offer or install claims; Windows and signed repositories stayed unavailable.
- Both live `llms` files exactly matched the merged source bytes, including the corrected
  FAQ. The desktop sitemap lastmod was 2026-10-13. This was normal deployment, not a new
  deploy commit or cloud command.

Local record: `build/landingpage-linux-preview/production-verification.json`, with
`verify-production.mjs`, screenshots, retrieved public verification files and separate
fixture/validation/merge records in that directory. This proves website delivery and
navigation only, not native Settings dispatch, GUI/sign-in/keyring/tray, installed-state
preservation, N→N+1 upgrades, stable Linux or repository trust.

The documentation-only acceptance record is step 11.f/14. Further stable/repository
work is not authorized by completion of this internal-preview slice.

## Original private-package implementation

- Add `.github/scripts/package_desktop_linux.py`, reusing native inventory and
  committed staging from existing tooling. Consume the current bundle's version,
  build number, source SHA, Linux OS and CPU; do not hardcode historical versions.
- Preserve the complete staged GUI/helper/assets/licenses below
  `/opt/sesori-desktop/`. Own `/usr/bin/sesori-desktop`, one desktop entry and a
  correctly sized application icon. Never replace the standalone bridge executable
  or own user homes, autostart, credentials, databases, runtimes or projects.
- Build native DEB using `dpkg-deb`; derive linked-library requirements with
  `dpkg-shlibdeps`, preserving bundled-library lookup. Check actual plugin source
  for `dlopen` runtime dependencies before adding explicit requirements.
- Build native RPM using `rpmbuild` in a pinned supported Fedora container on the
  matching native host; let RPM generate ELF dependencies. Do not claim Ubuntu
  rpmbuild alone validates Fedora dependencies. Freeze image release/digest after
  checking official availability; no emulation fallback.
- Extend the existing private qualification workflow with a manual Linux mode.
  Reuse native Ubuntu x64/arm64 SDK/bundle builds. Validate DEB installation/removal
  through actual package managers on isolated Ubuntu24.04/Debian13 containers and
  RPM through Fedora on the same native CPU. Do not run GUI or helper services.
  Preserve root-owned package paths and realistic shared-data sentinels; compare
  installed payload paths/hashes with staging. Retain packages and diagnostic
  evidence as private artifacts with the existing 14-day retention.
- `.github/scripts/test_package_desktop_linux.py` exercises synthetic identity,
  CPU, payload/layout, package metadata, dependency invocation and ownership rules.
  Run targeted Python tests and actionlint. Add precise supported behavior to
  `docs/regression/desktop-distribution.md` and record measured native source/run.

## Boundaries and proportionality

No new application classes, DI, services, state, transport/storage contracts,
shutdown owner or updater. Package managers own replacement and tracked-file removal;
no maintainer scripts launch processes or walk user homes. Existing autostart path
behavior stays unchanged; minor stale user autostart residue is accepted.
Architecture reviews are not required for this non-architectural tooling slice.

Estimate 740–1,020 authored lines including fixtures/workflow/docs; keep below the
1,500 soft cap and split cleanly if measured implementation grows beyond it. No
new mutable application state. Avoid general release catalogs, repository generators,
key rotation or broad package-manager abstractions. Real dependency failures justify
specific corrections, not guessed distribution support.

## Evidence and release gates

Native x64 and ARM64 remain required. Container install/dependency/file-ownership
checks prove package mechanics only, not desktop-session usability. Real GUI, tray,
Secret Service available/unavailable, login, account restoration, minimum-OS and
signed/public retrieval gates remain open. A same-version reinstall must not be
reported as an actual N→N+1 application upgrade. Missing environments are blockers,
not successful or silently dropped rows.

Implementation PRs use focused contracts and CI. Credential-bearing native/public
qualification follows merge through the main-only workflows; never substitute local
fixtures for that result. Observe each dispatched run with one owned completion watcher,
then inspect terminal evidence. Do not touch local GUI/bridge processes or execute
package installation on this Mac.

## Implementation and evidence checkpoints

Current tooling stages the complete bundle below `/opt/sesori-desktop`, owns that
payload plus only the `sesori-desktop` launcher, desktop entry and 512x512 RGBA icon,
derives DEB dependencies through strict `dpkg-shlibdeps`, and leaves RPM ELF
requirements to native Fedora `rpmbuild`. It audits every package named by generated
`FLUTTER_PLUGIN_LIST` for explicit dynamic loading. Package fixtures reject lifecycle
scripts, verify bounded package ownership and root-owned staged hashes/paths, perform
an honestly named same-version reinstall, remove package-owned paths, and preserve
shared-data sentinels without launching either payload. This paragraph describes the
current implementation; it is not a claim that review-fix inputs have passed native CI.

Fedora's official `https://fedoraproject.org/releases.json` listed 42, 43 and 44 as
releases while 45 was Beta when checked on 2026-09-16. The official registry supplied
multi-architecture index digest
`sha256:61beafd34111e1cb85fb49377ceadeee0a53622dbc20670ed8ca303f0e17ed9c`.
The workflow also pins the Ubuntu 24.04 index at
`sha256:69cecf4bbf72d2d44a9eef1b71fb98c7fb973d78af11399deccef19beb008ad9`
and Debian 13 at
`sha256:f324c7ff54321e8d9c588493a20244965938ce0aa50bbd1022d38010e9ffc4b1`.
Each pull is checked against its digest and native CPU. `apt`/`dnf` repositories remain
rolling; base-image pins do not make later package dependency resolution bit-reproducible.

PR #1522 merged this private qualification, accepting
`07bdd730e6451d221ebb86821a38c4252e4e0abc` as squash
`9f9081f71995397edf39690efc212aa0920c6175` on 2026-09-16. Accepted source tree:
`3e869292f7f11eeb6356cfd56a938c3c20976239`. The accepted PR source, not the squash
commit, is the artifact-producing revision.

Both native jobs used checkout cwd
`/home/runner/work/sesori_apps_monorepo/sesori_apps_monorepo`.
The exact build, dependency-generation, container and fixture commands are the
`linux-distribution` job at this immutable workflow revision, rather than a duplicated
command list that could drift:

```bash
source=07bdd730e6451d221ebb86821a38c4252e4e0abc
# Recover the producer object even in a fresh post-squash checkout.
git fetch origin refs/pull/1522/head
git show "$source:.github/workflows/desktop-qualification.yml"
# Expanded commands and measured job environment:
gh run view 35122448200 --repo sesori-ai/sesori_apps_monorepo --job 104883363575 --log
gh run view 35122448200 --repo sesori-ai/sesori_apps_monorepo --job 104883363460 --log
```

Both jobs passed. This identifies the executed instructions, not a promise of
bit-identical rebuilding against rolling package repositories.

Final native run [35122448200](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/35122448200)
passed native x64 and ARM64 jobs at that accepted source. Both jobs built DEB and RPM
packages and passed Ubuntu 24.04, Debian 13 and Fedora 44 install, same-version
reinstall and removal fixtures. The independently checked package SHA-256 values are:

| CPU | Format | SHA-256 |
|---|---|---|
| x64 | DEB | `6367ea24acf2eb2660493f0ee97a1dc23c46bd0688e67625c023f044a23105fa` |
| x64 | RPM | `c76b188d6c3df6536ed25beabe861e348a036517e43144e95739af320454afe2` |
| arm64 | DEB | `12bfcd3d35921f90422ea43dc77cbc8ecede8e069f39faef85618fe209d6ab2f` |
| arm64 | RPM | `1d2eff7f973d65d16c3136867c3fca97fb03d513e073d510b1ebee56ce713cd3` |

From this worktree root, artifacts were retrieved with `gh run download 35122448200
--repo sesori-ai/sesori_apps_monorepo --pattern 'desktop-linux-*' --dir
build/desktop-linux-packaging-evidence/native-07bdd73`. All four packages contain the
same expected 73 package payload files and 13 native ELF files for their CPU. Both
source patches are empty. Six native fixture results verify strict generated DEB
dependencies, Fedora-generated RPM ELF requirements, bounded package paths, absence
of DEB maintainer scripts/RPM scriptlets, pre-install shared-data sentinels, exact
root-owned installed payloads, same-version reinstall, removal of package-owned paths
and sentinel preservation. The retained independent summary is
`build/desktop-linux-packaging-evidence/native-07bdd73/verified-summary.json`.

Earlier failing attempts are historical CI evidence, not current unsupported-feature
markers and not regression assertions. This final run still does not establish
signing, publication, real N→N+1 update, GUI/session startup, account restoration,
Secret Service/keyring, tray, login launch, interactive desktop behavior or minimum-OS
support. No package or local GUI/helper was installed or launched on this Mac.
