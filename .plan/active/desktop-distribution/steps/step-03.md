# Step 3 — Identity-Bound Desktop Bundles

Status: **in progress** — implemented and locally verified; PR/native CI pending.

## Implementation

- `DesktopBundleIdentity` stays in desktop-core foundation, with generated JSON
  and closed desktop OS/CPU enums. No shared/wire/database contract changed.
- The build-time producer builds GUI and helper from one committed checkout,
  enforces dependency locks, supplies matching Flutter build defines, and preserves
  the complete helper/native assets and framework symlinks.
- Release resolution uses only the installed executable and validates the current
  manifest at the existing pre-spawn seam. Missing/mismatched bundles require
  restart/repair; debug/profile keeps development overrides. Lifecycle ownership
  remains unchanged, with no new mutable coordinator or polling.
- Desktop product semver joins version synchronization while retaining its own
  build suffix. Installer/publication channels are not introduced here.
- Removed obsolete development-only packaging/version guidance. No analytics event
  is added for this internal build/startup-integrity boundary.

## Local evidence

Implementation commit: `1d9f8ce`. Incoming main was merged, preserving both the
sidebar and bundle exports, as `350cb8e8c9cb18187ab8ed4cca6af5fc430e0a3c`.

- 3 identity, 30 resolver/staging and 7 version-sync tests passed.
- 11 Python qualification tests and actionlint passed.
- Desktop/core package analyzers and root version-tool analysis passed.
- Generated files were regenerated. Full owning-package generation restored the
  unrelated outputs removed by an initially filtered build_runner invocation.
- Native macOS ARM64 staging at `350cb8e`: release GUI + complete helper built,
  seven packaged native binaries including three helper binaries verified.
- Flutter compiler defines equal the helper manifest; native app version/build
  equal `1.8.4` / `1`. No tracked post-build changes. The relocated staged helper
  reports `1.8.4` and passes the one isolated supervised E2E test.
- Raw local evidence is under ignored `build/desktop-bundle-evidence/`.

## Architecture review

`medium-intelligence-fast` reviewed commit `350cb8e` from merge-base `ed9b15ba`,
using `architecture-implementation-review`, run
`05d41c7d-dd8d-4372-80a0-3028c92ba058`: **approved, no findings**. It confirmed
model, producer, resolver and lifecycle ownership; authenticity and actual installed
GUI/upgrade coverage remain later gates. The following CI-only cache placement fix
and evidence documentation do not alter the reviewed production architecture.

## Native CI and release boundaries

The six-target workflow now builds through the staging producer and inspects the
actual staged payload before relocating/testing its helper. Git stderr is separate
from machine-readable status, and post-build diffs are retained. The qualification
PUB_CACHE was moved outside the checkout in `44cf646`: dependency downloads are
untracked build inputs, not source changes to commit.

Current-head native CI remains pending. This evidence does not claim actual GUI/
account operation, minimum-OS execution, signed installers, real upgrades, or public
release readiness. No signing credentials, user application data, or publication
infrastructure were used. Parent and platform release gates remain open.
