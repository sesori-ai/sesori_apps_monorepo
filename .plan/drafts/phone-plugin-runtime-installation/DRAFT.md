# Phone-Requested Plugin Runtime Installation

## Status

Draft only. Not part of the setup-aware lifecycle implementation.

## Intent

Allow an authenticated client to request installation of a plugin-owned,
bridge-managed runtime when setup reports `runtimeMissing`.

Only pinned artifacts with verified checksums may be managed. Installation must
preserve the local E2E trust posture, expose observable progress/failure, and
finish by refreshing setup without enabling hidden automatic downloads.

Backend login, secret entry/storage, external installers, and concrete wire/UI
design remain undecided until this work is activated.
