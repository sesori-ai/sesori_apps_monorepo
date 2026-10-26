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
