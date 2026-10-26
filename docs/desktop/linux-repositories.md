# Linux repository operations

`linux-repository.yml` publishes signed APT/RPM metadata for the `internal` and
`stable` channels, each from its newest already-completed public Linux release. It
never builds applications, creates/promotes releases or dispatches stores.
Infrastructure or a passing fixture alone is not live publication: bootstrap requires
a successful main-branch run and anonymous verification of its actual output.

## Accepted internal delivery

[Run 38754986125](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/38754986125),
from merged #1997 (`50e59ba739f9cddae58e5b0ddc325b0d40e628a5`), published
`1.9.2-1022` on 2026-10-15 using protected production signing and the scoped Google identity.
Independent anonymous retrieval verified the pinned signatures, expiry and complete
index/package reference tree. Real APT and DNF clients refreshed and downloaded both
architectures over HTTPS; native RPM signatures also passed. Those client checks ran
in an ARM64 Fedora container, without installing or executing the application.

[Retained verification summaries](https://github.com/sesori-ai/sesori_apps_monorepo/pull/2002#issuecomment-6196620863)
include the independent verifier revision and the exact evidence boundary. This accepts
internal repository delivery only; stable repository delivery has no live acceptance yet.

## Package registration

Every DEB and RPM registers its compiled channel's repository on install, so the
system updater (Software Updater, GNOME Software, Discover, `dnf-automatic`)
delivers later versions without any manual setup. There are no maintainer scripts.
The registration is ordinary package-owned files, which removal deletes:

- DEB: `/etc/apt/keyrings/sesori.asc` and `/etc/apt/sources.list.d/sesori.list`.
  These are the website's manual-setup paths and line, so an earlier manual setup
  is replaced in place rather than duplicated (a duplicate with a different
  `signed-by` path would make APT reject both).
  `/etc/apt/apt.conf.d/52sesori-unattended-upgrades` adds `origin=Sesori` to
  unattended-upgrades' allowed origins, so where it is enabled (Ubuntu's default)
  updates install silently; the running app then offers "Restart to update".
  The in-app "automatic updates" toggle controls only the app's own checks and its
  "Restart to update" prompt; silent installs follow the system's unattended-upgrades
  or `dnf-automatic` configuration, so turning the toggle off does not stop them.
- RPM: `/etc/pki/rpm-gpg/RPM-GPG-KEY-sesori` and `/etc/yum.repos.d/sesori.repo`,
  with `skip_if_unavailable=1` so an unreachable Sesori repository never blocks
  the system's other updates. The repo file is `%config(noreplace)`, so a user's
  edit or disable survives upgrades.

APT has no skip setting. A stable DEB installed before the stable repository's
first publication makes `apt update` report an error for the Sesori source until
`linux-repository.yml` publishes, a few minutes later in the same release run.

The key comes from `client/desktop/linux/packaging/sesori-linux-public.asc`, a copy
of the published key. The install fixture fails if its fingerprints differ from
the key that signed the package checksums (and, for RPM, the package itself). When the signing subkey is extended or rotated,
update that file, and ship a release containing it before the old subkey expires
(currently 2027-10-13 06:51 UTC). Installs that never receive that release cannot verify
newer repository metadata.

## Ownership and triggers

- `desktop-linux-release.yml` calls the repository workflow after the existing
  immutable GitHub publication completes: internal from the shared cycle, stable from
  `submit-release.yml` production after `store-production` approval and the `release`
  job. Core/macOS assets stay untouched.
- Monday's metadata-only refresh also covers quiet release periods. Manual dispatch
  repairs failures or bootstraps existing qualified releases without store builds.
- All three paths share one non-cancelling concurrency group. Every run refreshes each
  channel that has a completed release, so a replaced pending run loses no channel.
  A `select` job lists those channels; signing and publication run one independent
  matrix leg per channel. Before the first stable Linux release, stable is skipped and
  the run still succeeds.
- Internal follows the newest completed `v<X.Y.Z>-internal.<N>` pre-release by package
  version, not the most recently republished old tag. Stable follows the newest
  non-draft `v<X.Y.Z>` carrying `desktop-linux-release.json`. Like macOS, that includes a
  release still held as a pre-release because `publish_bridge` was unticked.
- The `linux-signing` job downloads the original packages/checksums, builds tools
  before exposing secrets and signs in a network-disabled container. It checks both
  CPU headers, signed checksum inventories and native RPM signatures against primary
  `E6BF6EF7B203685F480D4A2E73B86E42F31FDAE7`. Package bytes never change.
- A separate job receives only public artifacts and bucket-scoped Google federation.
  It has no signing secrets. The verifier authenticates signatures and their complete
  index/package references, not merely the producer's `repository.json` inventory.

## Hosting and scoped authority

Public base: `https://storage.googleapis.com/sesori-ai-linux-packages`.
The bucket uses uniform bucket-level access in `europe-west1`, project `sesori-ai`.
`provision_linux_repository.sh` records one-time creation; it is not a repeatable
reset script. Inspect partial results before retrying a failed setup command.

The dedicated `linux-packages` identity pool and its GitHub provider allow only the
numeric Sesori repository/owner identities, `refs/heads/main`, and two direct or
reusable workflow identities: `linux-repository.yml` and `desktop-update-feed.yml`.
The second hosts the desktop update feeds under `desktop-updates/`
([update signing](update-signing.md)). IAM grants both the whole bucket, so that
prefix is enforced by the feed workflow's publisher, not by IAM. Service account
`linux-package-publisher@sesori-ai.iam.gserviceaccount.com` has
`roles/storage.objectUser` on this bucket only. `allUsers` gets only
`roles/storage.objectViewer`. Existing Firebase federation, Cloud Run source storage
and project-wide IAM grants are not modified. No service-account key is created.

Domain-restricted sharing initially rejected public read. The operator authorized a
scoped exception: tag `sesori-ai/linux-packages-public/enabled` is attached only to
this bucket, never the project or another resource. The project policy allows that
tagged resource and retains the previous domain allowlist as its default rule.
This is not a temporary project-wide disablement. Keep that default aligned if the
organization's domain allowlist changes. The publisher has no policy/tag-management
permission and cannot expand the exception. Public Access Prevention remains unchanged.

## Publication and retry

The publisher independently verifies the public key pin, both APT signatures, both
RPM metadata signatures, referenced hashes, package identities and the exact public
inventory. It rejects expired APT metadata and any extra unauthenticated file.

Upload order:

1. Unchanged packages, public key, APT by-hash objects and checksum-named RPM indexes.
   Existing identical bytes are accepted; conflicting bytes are refused. New objects
   use a generation-zero precondition. Old objects are never pruned.
2. Canonical APT package indexes.
3. `Release` and RPM `repomd.xml`, followed by detached signatures.
4. APT `InRelease` last, after anonymous byte verification of preceding objects.

Immutable objects use long-lived caching; replaceable metadata uses `no-store`.
Every uploaded object's anonymous SHA-256 must match. `repository.json` stays in CI;
there is no new public release pointer. RPM XML/signature replacement can briefly
refuse refresh; retrying is safe. This is not atomic multi-object publication.

Retry a failed publisher job using its original signed artifact. A newer published
RPM revision prevents an older failed run from rolling the channel back. Re-running
signing intentionally generates fresh metadata and signatures; do not assume their
bytes remain identical. Immutable packages and content hashes remain unchanged.
Key changes that conflict with the existing public key require explicit key-maintenance
handling; do not bypass the immutable-object check or generate a new release key.

## Freshness and repair

APT includes UTC `Date` and `Valid-Until` 30 days later. Weekly refresh signs fresh
metadata for the same accepted packages when no new release exists. A failed refresh
fails CI visibly; repair before expiry. Never disable client `Check-Valid-Until`.
Expired artifacts must be regenerated as metadata rather than replayed unchanged.
RPM signatures do not provide APT's expiry guarantee.

Manual repair/bootstrap, from a merged trusted workflow:

```bash
gh workflow run linux-repository.yml --repo sesori-ai/sesori_apps_monorepo --ref main
```

Stable packages come only from a stable-channel build of the approved release's
source and build number; internal binaries are never relabeled. To bootstrap a stable
release approved before Linux was wired, dispatch `desktop-qualification.yml` with
`mode=linux-packaging`, `channel=stable` and that release's source/build, then
`desktop-linux-release.yml` with `channel=stable`, the same `source_sha`, `version` and
`build_number`, and that `packaging_run`.

This command must never be replaced by dispatching the store-uploading shared cycle
merely to prove repository delivery. Website availability and installation guidance
follow live verification; the app still has no new updater or persistent state.

## Verification boundaries

Disposable-key, inert-package fixtures exercise real APT/DNF install/upgrade/remove,
wrong-key/content refusal, authentic expired APT rejection and metadata refresh.
The publication verifier also rejects modified references even when the producer
inventory is updated to match. Publication tests cover ordering, immutable conflicts,
retention, downgrade refusal, retries and failed anonymous delivery.

These tests do not establish native GUI/account behavior or genuine application
N-to-N+1 upgrades. Production-key signing, GitHub federation and public HTTPS delivery
require the actual main workflow and anonymous clients. See
[Linux signing](linux-signing.md) and [desktop distribution regression](../regression/desktop-distribution.md).
