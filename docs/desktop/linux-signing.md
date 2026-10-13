# Linux artifact-signing setup

Linux uses a dedicated OpenPGP key, not the Apple Developer ID certificate. No paid
certificate or external identity verification is required. Keep the certification
primary key offline; GitHub Actions receives only the protected signing subkey.

The shared Bridge build signs both Linux CLI archives with detached OpenPGP signatures.
The same key owner signs private native x64/arm64 desktop packages from **Desktop Native
Qualification** (`linux-packaging`, main only). RPMs receive native OpenPGP signatures.
Both RPM and unchanged DEB bytes are covered by a detached signature over SHA-256 checksums. This
is **not** an APT repository: APT normally authenticates signed repository metadata,
not a detached signature beside a manually downloaded DEB. Internal desktop attachment
uses the shared release described below. Stable Linux, public APT/RPM hosting and
desktop-session/upgrade qualification remain separate.

## 1. Generate once, on your Mac

If you already generated the Sesori key, skip generation and use that key's full
primary fingerprint. Do not create a replacement key for every release.

Choose a strong passphrase in GnuPG's prompt and save it in your password manager.
The certification key expires in two years; its signing subkey expires in one year.
Renew before expiry using the offline primary key and update the exported CI subkey.

```bash
brew install gnupg
export GPG_TTY="$(tty)"
KEY_HOME="$HOME/.local/share/sesori-linux-release-key"
KEY_UID="Sesori Linux Packages <support@sesori.com>"
install -d -m 700 "$KEY_HOME"

gpg --homedir "$KEY_HOME" \
  --quick-generate-key "$KEY_UID" rsa4096 cert 2y

KEY_FPR="$(
  gpg --homedir "$KEY_HOME" --with-colons --list-secret-keys "$KEY_UID" |
    awk -F: '$1 == "fpr" { print $10; exit }'
)"

gpg --homedir "$KEY_HOME" \
  --quick-add-key "$KEY_FPR" rsa4096 sign 1y

gpg --homedir "$KEY_HOME" --list-secret-keys --with-subkey-fingerprint
```

## 2. Configure the protected GitHub environment

In `sesori-ai/sesori_apps_monorepo` → Settings → Environments, create
**`linux-signing`**. Select a custom deployment-branch policy allowing **`main` only**;
do not allow PR branches or unrestricted tags. No new production approval gate is
introduced: this environment protects signing credentials, not publication authority.

| Setting | Kind | Value |
|---|---|---|
| `LINUX_GPG_PRIVATE_KEY` | Environment secret | ASCII-armored **secret subkey** export, with an unusable primary-secret stub. |
| `LINUX_GPG_PASSPHRASE` | Environment secret | The passphrase used to protect the signing key. |
| `LINUX_GPG_FINGERPRINT` | Environment variable | Full 40-character **primary** fingerprint, not a short key ID. |

Run in the same terminal where `KEY_HOME` and `KEY_FPR` are set:

```bash
(
  set -euo pipefail
  umask 077
  REPO="sesori-ai/sesori_apps_monorepo"
  key_export="$(mktemp)"
  trap 'rm -f "$key_export"' EXIT

  gpg --homedir "$KEY_HOME" --armor --export-secret-subkeys "$KEY_FPR" > "$key_export"
  test -s "$key_export"
  gh secret set LINUX_GPG_PRIVATE_KEY --repo "$REPO" --env linux-signing < "$key_export"

  gh secret set LINUX_GPG_PASSPHRASE --repo "$REPO" --env linux-signing

  gh variable set LINUX_GPG_FINGERPRINT \
    --repo "$REPO" --env linux-signing --body "$KEY_FPR"
)
```

The subshell stops on failure without changing your interactive shell options. The
private export must succeed before any GitHub setting changes; its temporary file is
removed on exit, including failure.

The **“Paste your secret”** prompt from `gh secret set LINUX_GPG_PASSPHRASE` wants
the key's passphrase, not the armored key or a GitHub token. Paste it into your terminal
and press Enter; never paste it into chat or put it in a command argument. The
`LINUX_GPG_PRIVATE_KEY` command receives file input and must not ask you to paste a key.
Separately, **GnuPG pinentry may legitimately ask for the passphrase during export**
when its agent cache has expired. Enter the same key passphrase and let export finish;
that GnuPG unlock prompt is not a GitHub secret prompt or an export failure.

Only secret **names**, the public fingerprint and environment policy should be
inspected through GitHub metadata. Never retrieve or log secret values for debugging.

## 3. Back up before removing the online primary key

Use an encrypted offline drive. Replace the example mount path below; keep the
passphrase separately in your password manager. Private exports and the revocation
certificate must never enter Git, Actions artifacts, release assets or chat.

```bash
BACKUP="/Volumes/YOUR_ENCRYPTED_DRIVE/sesori-linux-signing"
install -d -m 700 "$BACKUP"
umask 077

gpg --homedir "$KEY_HOME" --armor --export-secret-keys "$KEY_FPR" \
  > "$BACKUP/primary-and-subkey-secret.asc"
gpg --homedir "$KEY_HOME" --armor --export "$KEY_FPR" \
  > "$BACKUP/public-key.asc"
cp -X "$KEY_HOME/openpgp-revocs.d/$KEY_FPR.rev" \
  "$BACKUP/revocation-certificate.rev"
cmp -s "$KEY_HOME/openpgp-revocs.d/$KEY_FPR.rev" \
  "$BACKUP/revocation-certificate.rev" && echo "Revocation backup verified."
```

macOS `cp -X` omits extended attributes, which some encrypted/external volumes cannot
store. It does not change file contents. A successful comparison verifies the revocation
copy only; retain the original key directory until the complete secret-key backup can
be restored in an isolated GnuPG home. Do not weaken filesystem permissions or use
`sudo` to work around an extended-attribute warning.

After verifying the complete backup, keep the primary key only offline. The public
key and fingerprint may be shared; neither the secret export nor revocation certificate may.

## 4. Qualify signed packages from main

```bash
gh workflow run desktop-qualification.yml \
  --repo sesori-ai/sesori_apps_monorepo --ref main \
  -f mode=linux-packaging -f channel=internal
```

Both native CPU jobs build/qualify packages, then sign in the pinned Fedora tools
container with networking disabled. Only that signing step receives the two secrets.
The signer imports into a temporary GnuPG home, checks the configured full fingerprint,
uses a private temporary passphrase file, strips both secrets from child environments,
and removes its key material/agent after signing. Public-only verification precedes
container install/reinstall/remove fixtures; RPM local-package signature checking is required.

Private package artifacts contain DEB/RPM files, `sesori-linux-public.asc`,
`desktop-linux-checksums.txt` and its `.asc` signature. Separate evidence retains input
unsigned package reports plus `signing.json` with final signed hashes and the public
fingerprint. RPM signing changes its signature header/hash, never the installed payload;
DEB bytes remain unchanged. No private key, passphrase or keyring is uploaded.

This workflow never publishes a release, enables Linux admission, uploads to stores,
or creates cloud resources. A successful disposable-key CI fixture proves the signer
mechanics, not production-key access or native application behavior.

## 5. Linux CLI signatures and existing-release bootstrap

`_reusable-bridge-build.yml` waits for the six native builds, then calls the read-only
`_reusable-linux-cli-signing.yml`. Its main-only `linux-signing` job uses the same
network-disabled container and temporary key owner as desktop signing. Neither archive
is unpacked, executed or modified. Each `.tar.gz.asc` is verified with public material
before upload. Signing failure prevents the shared build from succeeding.

Internal and production releases publish both signatures and `sesori-linux-public.asc`
alongside the six archives and unchanged basename-keyed `checksums.txt`. Public archive,
signature and key bytes are checked anonymously after upload. Existing store approval,
release/tag ownership and the npm archive filters remain unchanged. These are **CLI**
archives, not desktop DEB/RPM packages. Installers and automatic updaters still enforce
SHA-256 checksums; adding signatures does not silently add OpenPGP enforcement to them.

Core release owners retain their existing archive-replacement and promotion behavior.
On a rerun/rebuild, they refresh signatures with their archive set, then use a read-only
`verify` command to check delivery. The upload is not atomic: assets may be visible
before the job completes. Missing or mismatched signatures fail manual verification;
this change does not add a stable-release promotion/rollback gate.

Trusted callers retain `secrets: inherit` for environment-only credential resolution;
they cannot map values from an environment bound only inside the called job. The earlier
[macOS cutover](../../.plan/completed/macos-signing-environment/PLAN.md)
records the failed declaration-only runs and successful inheritance correction. Only
the two GPG secrets are exposed to the signing step and passed into its container.

For an existing public release without signatures, set `TAG` to its exact shared tag:

```bash
gh workflow run sign-linux-release.yml --repo sesori-ai/sesori_apps_monorepo \
  --ref main -f tag="$TAG"
```

This downloads both archives anonymously, matches their GitHub asset digests and
published checksums, then signs those exact bytes. A separate publication job checks
that the public archives still match and adds only the public key and two signatures.
It does not rebuild binaries, replace archives/checksums, create/promote releases, move
tags, upload to stores or change Latest. Signing evidence stays in Actions artifacts.
A failed publication job can be rerun with its original signature artifact; a new
signing run can produce different signature timestamps and will refuse conflicting
published bytes rather than overwrite them.

## 6. Verify a CLI archive using the independently pinned key

Download the matching archive, its `.asc` and `sesori-linux-public.asc` from the same
public release. Choose `sesori-bridge-linux-arm64.tar.gz` instead for ARM64. With
GnuPG installed, verify before extracting or running anything:

```bash
(
  set -euo pipefail
  verify_home="$(mktemp -d)"
  trap 'gpgconf --homedir "$verify_home" --kill all; rm -rf "$verify_home"' EXIT
  chmod 700 "$verify_home"
  fingerprint=E6BF6EF7B203685F480D4A2E73B86E42F31FDAE7
  gpg --homedir "$verify_home" --batch --import sesori-linux-public.asc
  gpg --homedir "$verify_home" --batch --export "$fingerprint" > "$verify_home/trusted.gpg"
  test -s "$verify_home/trusted.gpg"
  gpgv --homedir "$verify_home" --keyring "$verify_home/trusted.gpg" \
    sesori-bridge-linux-x64.tar.gz.asc sesori-bridge-linux-x64.tar.gz
)
```

Exporting only the known primary fingerprint excludes unrelated keys that might be
bundled in a downloaded key file. Do not substitute a fingerprint supplied only by
that same download. Missing signatures on an older release are not evidence of signing.

## 7. Publish approved internal desktop previews

The shared internal cycle builds both native Linux CPUs with the same product source,
version and build number as Bridge/mobile, then attaches verified packages after core
finalization. Linux failure does not block core or macOS publication. Stable Linux and
public APT/RPM repositories are not admitted. GUI/login/keyring/tray and real N→N+1
checks remain unverified; users opt into those limitations by choosing internal previews.

For bootstrap, select an existing public shared **internal** release and set
`SOURCE_SHA`, `VERSION` and `BUILD_NUMBER` from its exact tagged product identity.
Build matching packages without submitting anything to stores:

```bash
gh workflow run desktop-qualification.yml --repo sesori-ai/sesori_apps_monorepo \
  --ref main -f mode=linux-packaging -f channel=internal \
  -f source_sha="$SOURCE_SHA" -f build_number="$BUILD_NUMBER"
```

After both native jobs succeed, set `PACKAGING_RUN` to that run ID, not its run ordinal:

```bash
gh workflow run desktop-linux-release.yml --repo sesori-ai/sesori_apps_monorepo \
  --ref main -f packaging_run="$PACKAGING_RUN" -f source_sha="$SOURCE_SHA" \
  -f version="$VERSION" -f build_number="$BUILD_NUMBER"
```

The publisher has no signing secrets. It pins the approved primary fingerprint in
repository code, independently of producer artifacts or environment configuration.
A primary-key rotation requires explicitly updating that pin and these verification
instructions; renewing a signing subkey does not change the primary fingerprint.
It also requires retained compiled identity/channel, matching signed/unsigned evidence,
all six native package fixtures, valid checksum signatures, and a pre-existing public
internal tag that resolves to the exact source.
It cannot create/promote a release, change Latest/tags or replace conflicting assets.
Retry a failed publication job at its original workflow revision with its original
producer artifacts; do not rebuild or relabel private qualification build 147.

Public package names are `Sesori-linux-<arch>-<version>-<build>.<deb|rpm>`. Each CPU
keeps its original signed checksum bytes, renamed to
`desktop-linux-<arch>-checksums.txt` and `.txt.asc`. Verify them with the separately
named `desktop-linux-public.asc` and the same independently pinned primary fingerprint
used above; the desktop publisher never replaces `sesori-linux-public.asc` owned by
core CLI publication. After verifying the checksum signature, compare the selected
package's SHA-256 before installation. These are artifact checks, not repository setup.

`desktop-linux-release.json` is published last, after anonymous hash checks of all
packages and verification files. It is independent of macOS `desktop-release.json`.
Internal rollover retains the newest completed preview per platform; stable/npm cleanup
preserves those previews instead of redirecting internal users to stable.

## Verified public CLI bootstrap

Main-only [run 38412243041](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/38412243041)
added signatures/key to existing public `v1.9.0`. Independent pinned public verification
passed for both unchanged archives; original checksums/assets, release metadata, tag
and Latest stayed unchanged. [Exact provenance and hashes](../../.plan/active/desktop-distribution/steps/step-09.md)
keep this proof separate from desktop packages and automatic updater enforcement.

## Verified public internal desktop preview

Native [run 38438783418](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/38438783418)
aligned both CPUs with shared `1.9.1+1013`, retained compiled internal identity and passed
all six native package fixtures. Publisher `38443588001`, with no signing-secret access,
attached the original artifacts to the existing release. Independent anonymous verification authenticated
both checksum signatures against the known primary and matched all four package hashes.
Original core/macOS asset identities, release content/channel, tag, Latest and original
checksum/manifest bytes were preserved. No store submission, local install or cloud setup ran.

Website PR `sesori-ai/landingpage#112` now discovers these previews. Live desktop/mobile navigation,
package/verification links, metadata and spacing were checked after normal deployment.
[The acceptance record](../../.plan/active/desktop-distribution/steps/step-09.md)
separates exact package, signature and website evidence from still-unverified
GUI/account/keyring/tray and real N→N+1 behavior. Stable Linux and repositories remain gated.

## Verified private qualification

[Run 38372268594](https://github.com/sesori-ai/sesori_apps_monorepo/actions/runs/38372268594)
qualified both native CPUs on 2026-10-13 after #1941 merged. Private `1.9.1+147` RPMs
received native signatures; signed checksums covered both formats, leaving DEB bytes
unchanged. All six native container package fixtures passed. Independent downloaded
hashes and public-key-pinned checksum
signatures matched. See [the acceptance record](../../.plan/active/desktop-distribution/steps/step-09.md)
for the exact source tree, measured checkout cwd, immutable workflow revision,
expanded native job logs/commands, fingerprint and package-file hashes.

This proves the configured signing path works. It does not admit public repository
publication or establish GUI/account/keyring/tray behavior or real N→N+1 upgrades.
Qualification build 147 is not a shared bridge/mobile release number and remains private.
Public build 1013 was separately qualified with its exact shared source/build/channel;
build 147 must never be relabeled as that or another shared release.
