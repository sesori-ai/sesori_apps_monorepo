# Linux repository preparation

Signed repository generation is implemented; hosted repositories and stable Linux
publication are not yet enabled. Direct internal DEB/RPM downloads remain available.
See [signing trust and key custody](linux-signing.md) and the active
[distribution continuation](../../.plan/active/desktop-distribution/steps/step-09.md).

## Ownership and input

`.github/scripts/build_linux_repository.py` consumes the directory emitted by the
existing Linux release preparer: `desktop-linux-release.json`, four signed/qualified
DEB/RPM packages, two original checksum/signature pairs and `desktop-linux-public.asc`.
The preparer remains responsible for source/native qualification and compiled channel
identity. The repository builder does not grant release approval or turn an internal
binary into a stable one.

The builder checks both package sets against signed checksums, independently pins the
primary signer, checks DEB/RPM headers and verifies native RPM signatures. Package
bytes remain unchanged. `apt-ftparchive` and `createrepo_c` own index generation;
there is no custom package parser, updater, daemon or release database.

## Protected execution

Build `.github/scripts/Dockerfile.linux-signing` as `sesori-linux-signing` first, then
`.github/scripts/Dockerfile.linux-repository` as `sesori-linux-repository`. The second
image extends the locally built pinned signer with repository tools; ordinary CLI and
native package signers do not install those additional dependencies.

Only after both builds finish may the existing protected signing job supply
`LINUX_GPG_PRIVATE_KEY`, `LINUX_GPG_PASSPHRASE` and `LINUX_GPG_FINGERPRINT`. The CLI pins
`E6BF6EF7B203685F480D4A2E73B86E42F31FDAE7` independently of producer configuration.
Use a network-disabled container. Mount the trusted workflow checkout read-only at
`/workspace`, prepared input read-only at `/prepared`, and an owned output volume at
`/output`. Use a fresh output directory. Inside that container:

```bash
python3 .github/scripts/build_linux_repository.py \
  --root /prepared \
  --output /output/repository \
  --channel internal
```

The shared temporary key owner removes secret variables before child tools run,
verifies repository signatures with public material, and cleans its private agent/home.
`repository.json` is written only after successful signing, verification and cleanup.
It is a CI file inventory, not a public release pointer. Failed/partial output must not
be published. Retry publication from the original signed artifact rather than assuming
fresh signatures will be byte-identical.

## Repository layout and publishing contract

```text
sesori-linux-public.asc
apt/
  pool/<channel>/<amd64|arm64>/Sesori-linux-<cpu>-<version>-<build>.deb
  dists/<channel>/Release
  dists/<channel>/Release.gpg
  dists/<channel>/InRelease
  dists/<channel>/main/binary-<amd64|arm64>/Packages[.gz]
  dists/<channel>/main/binary-<amd64|arm64>/by-hash/SHA256/<digest>
rpm/<channel>/<x86_64|aarch64>/
  Packages/Sesori-linux-<cpu>-<version>-<build>.rpm
  repodata/<checksum-named metadata>
  repodata/repomd.xml
  repodata/repomd.xml.asc
```

`internal` and `stable` are separate suites/pools and RPM roots. This does not install
both channels or introduce an in-app switch. The later publisher must:

1. Preserve immutable package bytes; refuse conflicting existing package paths.
2. Publish public key, packages and content-addressed indexes before entrypoints.
3. Retain old package/index objects referenced by previously downloaded metadata.
4. Publish APT `InRelease` last for its suite. APT advertises only SHA-256 by-hash URLs.
5. Publish RPM signatures before their `repomd.xml`; require both `repo_gpgcheck=1`
   and `gpgcheck=1` in client configuration. Separate XML/signature replacement can
   briefly refuse a refresh; retry is safer than adding a custom transaction service.
6. Verify anonymous retrieval independently before advertising repository availability.

No GCS/IAM or public object changes occur in the builder. Hosting/publishing is the
next continuation; never interpret this document as a live installation command.

## Verification boundary

PR CI runs disposable-key fixtures in the pinned Fedora-derived tool image with
network disabled. It checks both architecture headers, both channel layouts, APT
cleartext/detached signatures, RPM metadata signatures, by-hash/content inventories,
unchanged package bytes and refusal of mismatched or altered inputs.

Real APT/DNF clients use fresh isolated roots, enforce metadata/package trust, and
install, upgrade and remove inert text-only packages while preserving unrelated state.
Wrong keys, altered metadata and altered package bytes must fail. These are repository
mechanics, not native application upgrades, production-key access, public HTTPS
availability or GUI/account/keyring/tray qualification on Ubuntu/Debian/Fedora.
