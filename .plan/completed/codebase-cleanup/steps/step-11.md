# Step 11/45 — Add plugin-local test support for OpenCode, ACP, and Pi

## Re-verification against `main`

OpenCode still had three `OpenCodeApi` fakes totaling 579 lines. They differed
in scenario state but repeated the same API surface, so one configurable
`FakeOpenCodeApi` now owns their combined behavior and call recording. The
plan's raw fixture audit found 84 `Project` and 51 `Session` constructions, but
many encode the behavior under test through timestamps, parentage, sandbox
paths, metadata, or `GlobalSession`. The 21 default-shaped construction/helper
sites use `openCodeProject` or `openCodeSession`; behavior-bearing variants stay
explicit.

ACP had 14 repeated `TestAcpPlugin` compositions across 11 tests. A single
`composeTestAcpPlugin` now creates fresh command/configuration trackers and
wires the event mapper and session-options service to those same instances.
The custom redaction launch spec remains an override. Cursor, OMP, and Hermes
composition stays local because those plugins own backend-specific catalogs,
cleanup, and option services rather than repeating the neutral ACP bundle.

Pi had four `PiSessionStorageApi` fakes, but not one common successful method
surface. Shared catalog, extension, and service variants now inherit only their
common state. The process repository's missing/exact-path fakes and both
history-storage fakes remain local because their strict capabilities are
scenario-specific.

## Review corrections

Review found two behavior regressions in the first consolidation. OpenCode's
shared fake filtered child sessions before `OpenCodeRepository` could exercise
its own filtering; root filtering is now opt-in only for the tracker profile.
Pi's first shared fake returned successful defaults for methods that several
former fakes deliberately left unsupported; capability-specific variants now
preserve each former fake's exact supported and fail-loud surface. Review also
caught legacy fake bodies left inside block comments, which were deleted rather
than retained as an alternate implementation.

Follow-up review reported no remaining OpenCode findings. Its final Pi note
that the missing-session process fake had lost its no-op marker cleanup was
also corrected.

## Verification

`dart analyze --fatal-infos` clean in `sesori_plugin_opencode`,
`sesori_plugin_acp`, `sesori_plugin_pi`, `sesori_plugin_cursor`,
`sesori_plugin_omp`, and `sesori_plugin_hermes`. `dart test`: OpenCode 434, ACP
260, Pi 260, Cursor 136, OMP 52, Hermes 38 — **1,180 tests passed**.

Size, excluding this evidence file, via
`git diff --numstat "$(git merge-base HEAD origin/main)"...HEAD -- bridge/sesori_plugin_acp bridge/sesori_plugin_opencode bridge/sesori_plugin_pi`
against merge-base `8f857ed22`: **`+582 / -1,351` = 1,933 changed lines**.
This is 433 lines over the 1,500-line soft cap, but is deletion-heavy and ends
at **769 fewer test/support lines** across the three packages.

Architecture implementation review not run: the new ACP export is explicitly a
test-only library; the change does not alter production behavior, dependency
ownership, or contracts.
