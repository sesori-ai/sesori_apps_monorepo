# Step 7.c — Settings modal

## Delivered behavior

General/Harnesses/Bridge/Notifications/Account are root-modal presentation, not product routes.
The session element/composer remain mounted; the merged [overlay prerequisite](step-07b.md)
pauses covered-session activity and dismisses popups before notification navigation.
General owns startup preferences; connected-bridge settings and local diagnostics stay distinct.
Harness Back stays internal; owned Close does not cancel upstream authentication. Account retains
supervised logout and auth-rejection dismissal. Mobile profile chrome stays unchanged; no database/wire changes.

## Combined-branch verification

Flutter 3.47.4/bundled Dart; cwd `client/desktop`. Checkpoints:
- A: `266d7b9b3c0c10d9a6e9d855e66812c111a8afd2`, tree `276f9d88e295d567f640972a662b624c708e097a`.
- B: `e098efac6fbe7003226e19c61534a02e629ddb62`, tree `e795b80d9b65c2e98c8be7c804048037d4f3a7ee`.

Each test path below is an argument to `flutter test --no-pub --reporter json`:

| Path | Checkpoint | Retained passing cases |
|---|---|---|
| `test/core/widgets/desktop_escape_dismissal_test.dart` | A | 3 |
| `test/core/widgets/desktop_cockpit_shell_test.dart` | A | 26 |
| `test/core/platform/desktop_route_dispatcher_test.dart` | A | 3 |
| `test/core/routing/desktop_router_test.dart` | A | 12 |
| `test/features/new_session/desktop_new_session_screen_test.dart` | A | 3 |
| `test/features/settings/desktop_settings_screens_test.dart` | B | 14 |

**61 distinct desktop cases**, not accumulated reruns. A ran all six suites together: exit 1,
59 passed/two failed. Its 12 modal passes are superseded by B's 14-case modal-only run, exit 0.
The failures exposed a pre-existing 2px `PregoNavTitle` toolbar overflow at 250% text, not rail overflow.
That checkpoint did not fix or pass the cosmetic limit. The later [step 11 audit](step-11.md) records its correction
and separate 250% evidence; these historical runs remain unchanged. B tests 100%/200% at 560×480,
asserting actual rail scrolling, unchanged text scale, popup visibility gating and retained opener identity.
`dart analyze --fatal-infos` in the same cwd at B: exit 0. No unchanged suite was repeated for provenance.
Logs/manifests: `/tmp/rose-elephant-settings-modal-{integrated-tests,rail-tests,integrated-analyze}.*`
and `/tmp/rose-elephant-settings-modal-followup-summary.json`.

## Historical evidence and rendering

The [original 87-case ledger](https://github.com/sesori-ai/sesori_apps_monorepo/blob/8d9faed46f74f14c8078196d963a6f29ee113d78/.plan/active/desktop-ux/steps/step-07b.md)
remains revision-scoped, not added to the 61 above. Mobile's unchanged 30 settings cases and shared-UI/mobile
analyzers remain at `5eae78681d8de54cd8efc411989d612470662ba1`; they were not rerun for this desktop-only follow-up.
The historical 12-modal-case/auth-owner run was `16e878ab20133601bdd38021bcde74b57dd75261`,
tree `ed1dc44512294b33d579ed281455b882b121e53d`, not a post-retirement rerun. The post-retirement analyzer's
uncommitted tree hash was **not captured**. Old-head `8d9faed` CI 13/13 is separate evidence.

Nine original real-font fixtures were inspected: five at `f4187384169afc8bf75b27bed358b8eab40837f7`;
Account, harness overview/detail and minimum startup at `fb135f863f1f92810481e572de013d3aa1fa8949`.
They were deliberately not rerun at the geometry-neutral `16e878a` auth follow-up or test retirement.
At B, `flutter test --no-pub --reporter json .dart_tool/settings_modal_preview_test.dart` passed three
fresh inspected renders: `settings-general-light-followup.png`, `settings-minimum-large-text.png`,
`settings-minimum-large-text-account.png`, under `/tmp/rose-elephant-qa.mri9JX/`. The 200% rail scrolls;
labels wrap rather than suppressing scale. Fixture SHA/command are in the `rail-previews.json` manifest.
All images are synthetic production-widget renders, not native/live QA or user approval; no renderer changed.

## Review, sizing and remaining qualification

The original architecture approval covers `ae9b093067810e784ebd41ddd5daa371d009d076..16e878a` only.
The final integration review approved frozen `f1e3276591d5f54137eec776c219b8964af933b2..e098efa`, no findings
(run `abce9cae-fff3-49e8-885e-b61945eacb31`); later changes are documentation only.
For historical `git diff --numstat ae9b093067810e784ebd41ddd5daa371d009d076 <head>` snapshots:
`e04597062568e4dc4aa9be61a4a6648ba66d3fc2` = 947+694 = 1,641;
`8d9faed46f74f14c8078196d963a6f29ee113d78` = 951+774 = 1,725.
The 84-line increase includes 80 test deletions and four net documentation lines; the ceiling rose by 100.
Every path is counted, including evidence/tests. Current pinned publication totals belong to PR #1501's body.

The live GUI/bridge/helper, production DI/auth/preferences, native registration and bundle stayed untouched.
Production-wired smoke remains CI-only. Native keyboard/backdrop/accessibility, live flows/preferences,
relaunch, lifecycle and energy checks remain required, not passed or waived; unavailable QA is not a delivery gate.
