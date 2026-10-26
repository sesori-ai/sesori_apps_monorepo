# Desktop update signing

One Ed25519 key signs every desktop update:

- the Sparkle appcast enclosures (`sparkle:edSignature`);
- the Velopack feed signatures (`releases.<channel>.json.sig`).

Installed apps trust only the public key compiled into them. Write access to the feed
bucket alone therefore cannot ship a build.
`.github/scripts/sign_desktop_update.py` signs and verifies. Public keys and signatures
are base64 of the raw Ed25519 bytes, which is Sparkle's format.

## Key setup (operator, once)

Generate the key on a trusted machine. Agents and CI logs never see the private key.

```bash
openssl genpkey -algorithm ed25519 -out sesori-update-key.pem
python3 .github/scripts/sign_desktop_update.py public-key --key sesori-update-key.pem
```

1. Create the GitHub environment `desktop-update-signing`, limited to the `main`
   branch, with no required reviewers. Production publication is already gated by
   `store-production`.
2. Store the PEM as its secret `DESKTOP_UPDATE_SIGNING_KEY`:
   `gh secret set DESKTOP_UPDATE_SIGNING_KEY -R sesori-ai/sesori_apps_monorepo --env desktop-update-signing < sesori-update-key.pem`
3. Keep an offline backup of the PEM, then delete the working copy.
4. The printed public key is not secret. It is compiled into the apps as Sparkle's
   `SUPublicEDKey` and as the Velopack feed verifier key.

## Published feeds

Each feed lives at
`https://storage.googleapis.com/sesori-ai-linux-packages/desktop-updates/k1/<channel>/<os>-<arch>/`.
Internal and stable are separate feeds. Internal builds never reach the stable feed.

| Target | Files | Published by |
|---|---|---|
| `linux-x64`, `linux-arm64` (AppImage) | `releases.<channel>.json`, its `.sig` and the full `.nupkg` | the internal cycle and production `submit-release`, after the Linux release assets are public |
| `macos-arm64`, `macos-x64` | `appcast.xml`; its one enclosure is the public release ZIP | the same workflows, after the macOS release assets are public, while `DESKTOP_MACOS_PUBLICATION_ENABLED` is on |
| `windows-*` | not published | Windows installers are not on GitHub Releases yet |

`desktop-update-feed.yml` does the work in two jobs:

- The signing job runs in `desktop-update-signing` and holds only the key. It refuses a
  secret that is not the compiled public key. It refuses a feed whose version differs from
  the release, and a ZIP whose app differs from the release.
- The hosting job holds only the bucket federation. It checks every signature again
  against the compiled key, and refuses any object outside `desktop-updates/k1/<channel>/`.
  It uploads packages first, with a generation-zero precondition and immutable caching.
  Then it uploads the feeds, then their signatures, with `no-store`. It checks each
  object's anonymous HTTPS bytes.

A failed hosting job can be rerun from its signed artifact. Swapping a feed and its
signature is not atomic: a client that checks in between refuses the feed and retries at
its next check. Old packages are never pruned.

## Rotation and compromise

Feed URLs carry a key ID (`k1`, `k2`, …), and each build reads the feed for its own key.

To rotate:

1. Ship a release signed with the current key that compiles in the next key and its
   feed path.
2. Freeze the old key's feeds at that release, so installs that missed it can still
   catch up.
3. Sign every later release with the new key.

If the key is compromised:

1. Stop feed publication.
2. Rotate as above.
3. Tell affected users to reinstall manually from GitHub Releases, because the old
   feed can no longer be trusted.
