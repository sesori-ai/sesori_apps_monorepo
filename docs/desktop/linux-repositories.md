# Linux preview repository operations

`linux-repository.yml` publishes signed APT/RPM metadata for **internal previews
only**, using already-completed public Linux releases. It never builds applications,
creates/promotes releases or dispatches stores. Stable admission and native desktop,
account/keyring/tray and genuine application-upgrade qualification remain separate.
Infrastructure or a passing fixture alone is not live publication: bootstrap requires
a successful main-branch run and anonymous verification of its actual output.

## Ownership and triggers

- `desktop-linux-release.yml` calls the repository workflow after the existing
  immutable GitHub preview publication completes. Core/macOS assets stay untouched.
- Monday's metadata-only refresh also covers quiet release periods. Manual dispatch
  repairs failures or bootstraps existing qualified previews without store builds.
- All three paths share one non-cancelling concurrency group. Selection chooses the
  newest completed internal package version, not the most recently republished old tag.
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
numeric Sesori repository/owner identities, `refs/heads/main`, and the repository
workflow's direct or reusable workflow identity. Service account
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
