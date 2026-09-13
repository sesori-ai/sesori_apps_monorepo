# Step 7 — Shared ACP Multi-select

## Outcome

Implemented the approved array-question mapping without changing any runtime
target, compatibility floor, launch/authentication policy, public wire field,
database schema, or client production code. DeepSeek remains excluded from this
series. The live OMP/client roundtrip is **not run**, not a delivery hold or a
claimed pass.

The branch is based on Step 6's squash merge
`acc970cf8452dcb58d5eff085f4ebfbabefb8110` (PR #1467, merged
`2026-09-13T12:00:25Z`; terminal CI 16/16, current-head automated reviews settled,
one tracker-wording thread corrected/resolved).

## Implementation and ownership

The only production change is in
`bridge/sesori_plugin_acp/lib/src/repositories/mappers/acp_elicitation_mapper.dart`:

- An array with finite `items.anyOf` string-`const` alternatives becomes an
  options-only checkbox question (`multiple: true`, `custom: false`).
- The private immutable `_ArrayEnumField` maps every selected display label
  back to its original value, preserving answer order. Its label/value map is
  unmodifiable and detached from the source schema.
- Existing titled scalar `oneOf` parsing is reused for the array alternatives;
  scalar enum, boolean and custom-text behavior remains unchanged.
- Every property keeps its original question index, key and required flag. A
  separate string property remains a separate text question; no OMP `qN` or
  `qN__other` convention appears in the shared mapper.
- Empty optional answer slots omit only their own property. A missing required
  answer declines the form. Unsupported arrays decline without exposing
  labels/defaults or leaving a pending request.

Existing ownership remains intact: OMP's live plugin advertises form support;
`OmpAcpApi.open()` keeps scratch/catalog/cleanup form support disabled. The
bridge's plugin-to-shared mapping and `QuestionRepository`, shared
`QuestionInfo`/`ReplyAnswer`, and existing `QuestionModal` need no production
changes. Existing authoritative question-answer analytics are reused.

The OMP test is a **synthetic**, upstream-shaped fixture, not a native capture.
It follows the published `askDialog` builder in
[`acp-agent.ts`](https://github.com/can1357/oh-my-pi/blob/e4dd2ec3b487f216c569281e2cdb7ec476a81f2e/packages/coding-agent/src/modes/acp/acp-agent.ts#L468-L507):
array options and a separate string property. Retained source evidence and the
Step 5 incremental comparison establish that this path was unchanged between
18.1.18 and 18.1.19; no new candidate parsing or execution was performed here.

## Executed verification — 2026-09-13

Used the pinned Flutter `3.47.4-stable` / Dart `3.13.3`. The client workspace
initially lacked package configuration, so it was prepared once using
`flutter pub get --offline --enforce-lockfile`; cached resolution succeeded and
no tracked dependency or generated files changed. Bridge dependency setup was
not repeated. Five changed Dart files were formatted before testing.

| Owning package | Focused suite | Successful cases |
|---|---|---:|
| `bridge/sesori_plugin_acp` | `test/acp_elicitation_test.dart` | 23 |
| `bridge/sesori_plugin_omp` | `test/omp_plugin_test.dart` | 15 |
| `bridge/app` | `test/bridge/repositories/question_repository_test.dart` | 16 |
| `client/module_app_ui` | `test/features/session_detail/widgets/question_modal_test.dart` | 21 |
| **Total** | **Four suites** | **75** |

Each bridge suite ran with `dart test --reporter=json <suite>`. The widget suite
ran with `flutter test --no-pub --reporter=json <suite>`. Counts use non-hidden
`testDone` events matched to `testStart` and suite identity: no counted failures
or skips, and all four `done.success` values are true. All four owning packages
also passed `dart analyze --fatal-infos`. Full repository test/analyzer coverage
remains CI-owned. Documentation scope/privacy/whitespace checks passed, including
27 relative links across five Markdown files and nine synchronized series titles.

Focused evidence covers:

- multiple selected values, duplicate display-title disambiguation, separate
  identical custom text, and each property's independent omission/required flag;
- seven unsupported array shapes, structural-only diagnostics, no pending
  residue, and response encoding independent of mutable source choices;
- synthetic OMP ACP response keys/types, live form advertisement and absent
  scratch advertisement, alongside existing session routing;
- plugin-to-shared checkbox/custom flags, typed shared reply serialization, and
  ordered array/custom/empty slots reaching the plugin unchanged;
- existing checkbox UI with no custom input on the array page, two selections,
  a separate identical text answer or optional per-question decline;
- existing scalar choice/custom behavior, single-question rejection, and ACP
  reject/abort/disposal semantics.

Local command records and full test/analyzer streams are retained under
`.dart_tool/runtime-refresh-validation/step-7/checks/`. Those are private local
artifacts, not native/runtime or external-provider evidence.

## Review and scope

The five Dart files total **435 additions plus deletions**: 77 production and
358 test lines, with no generated churn. Actual implementation complexity is
**🌿 straightforward**: one existing mapper and a private field variant, with
existing cross-layer contracts reused. No lifecycle or coordination machinery
was added. Architecture implementation review approved commit
`266babbf85f39e41769d1e316ffdae5d47587702` with no findings, confirming the mapper's
ownership, immutable encoder, and unchanged cross-layer contracts. This is
architecture approval, not native or end-to-end verification.

Feature-owned [question regression coverage](../../../docs/regression/questions-and-permissions.md)
and [capability notes](../../../docs/HARNESS_CAPABILITIES.md) land with this
implementation. No obsolete production path, model, flag or storage was created
or made removable by this additive mapping.

## Remaining L2 evidence

On at least one supported client, an authorized real OMP `18.1.19` `askDialog`
must complete an ACP array roundtrip: two selections, separate custom text
identical to an option, optional omission, required omission/rejection,
cancellation and unchanged single choice. Widget tests and fake ACP frames are
not that evidence. No live fixture was used and no credentials, user profiles,
provider sessions, native runtime or platform-specific installation were accessed
for this step.

This remains a concrete grouped follow-up in Steps 8–9, along with the previously
recorded runtime/platform checks. The stopped Codex/Hermes procedures are not
reauthorized. Keep the plan active until final coverage is completed or its
limits are explicitly accepted, as required by [PLAN.md](PLAN.md).
