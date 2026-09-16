# Step 6 — Private release preparation and publication gate

Ordinal 8/14. Builds on merged step 5 (#1506). Public publication remains blocked;
this implementation prepares evidence without tags, releases, signing, website
writes, new credentials, or changes to CLI/mobile finalizers.

## Code-informed implementation boundary

- `.github/workflows/desktop-release.yml` is manual and read-only. It downloads
  both CPUs' private packages/evidence from one successful qualification run.
  Source SHA, run ID and channel are explicit inputs; this workflow is macOS-only.
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

## Release isolation and blockers

Proposed tags use `desktop-vX.Y.Z` or `desktop-vX.Y.Z-internal.N`. Explicit bridge
selectors require a `v` prefix, so desktop tags do not qualify. Generic GitHub
Latest is repository-wide: eventual publication must use `--latest=false` for
both desktop channels. This step generates a proposed tag but never creates it.
It neither consumes mobile/CLI versions nor moves `internal-release-attempt`.

Do not claim step 6 shipped from preparation. Remaining gates:

- Owner-approved migration of repository signing credentials, including shared CLI
  consumers and removal of repository copies, into protected environments.
- Both native macOS manual upgrade/data-preservation gates and parent desktop-app
  prerequisites; existing private package probes do not establish these.
- Live `https://sesori.com/desktop/` and verified public download links. The URL was
  explicitly selected by the user before the page existed.
- Actual immutable publication and public retrieval/signature checks, then channel
  metadata last. No publication credentials or hosted resources are provisioned here.

No automatic updater layers remain to clean up. The private producer stays separate
from public release authority. Windows/Linux publication remains disabled.

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
