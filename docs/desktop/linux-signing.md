# Linux package-signing setup

Linux uses a dedicated OpenPGP key, not the Apple Developer ID certificate. No paid
certificate or external identity verification is required. Keep the certification
primary key offline; GitHub Actions receives only the protected signing subkey.

Current scope: private native x64/arm64 packages from **Desktop Native Qualification**
(`linux-packaging`, main only). RPMs receive native OpenPGP signatures. Both RPM and
unchanged DEB bytes are covered by a detached signature over SHA-256 checksums. This
is **not** an APT repository: APT normally authenticates signed repository metadata,
not a detached signature beside a manually downloaded DEB. Public APT/RPM hosting,
shared-release attachment and desktop-session/upgrade qualification remain separate.

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
introduced: this environment protects private qualification credentials, not publication.

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

## 4. Qualify signed packages after the PR merges

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
