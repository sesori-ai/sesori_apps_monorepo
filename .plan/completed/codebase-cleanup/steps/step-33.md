# Step 33 — `NewSessionState` phase + configuration

The new-session state repeated the same six composer configuration fields
across five flow variants. This step separates that independent configuration
from the creation phase while preserving the existing behavior.

## Re-verification against `origin/main`

- `idle`, `sending`, `restoringSubmission`, `creationError`, and
  `discoveryError` still carried the same six configuration fields.
- `agentModelData` still repeated their destructuring before projecting the
  same composer data for every non-created state.
- Discovery success intentionally clears a discovery error, while restoration
  and creation errors survive discovery, options, project-capability, and
  reconnect updates.
- A failed submission's snapshot remains identity-stable until the screen
  acknowledges it. A command submission also restores its staged command.
- Configuration may still change while a session request is in flight, and a
  failed request restores from the latest configuration.
- The app only distinguishes sending, restoration, and error presentation;
  there are no desktop consumers of the concrete new-session variants.

## What changed

- Added `NewSessionComposeConfig` for the six shared composer configuration
  fields and moved the `AgentModelData` projection onto it.
- Added sealed `NewSessionPhase` variants for idle, sending, submission
  restoration, creation failure, and discovery failure.
- Reduced `NewSessionState` to `composing({config, phase})` and
  `created({session})`.
- Replaced full state reconstruction in `NewSessionCubit` with configuration or
  phase copies, retaining phase-owned submission and failure data by default.
- Updated the mobile presentation and focused tests to match the composed
  state. Added one reusable phase matcher for the core tests.
- Regenerated the Freezed output from the annotated source.

Change-budget totals exclude this evidence file and use the merge base with
`origin/main`:

```bash
BASE=$(git merge-base HEAD origin/main)
git diff --numstat "$BASE"...HEAD -- client/module_core/lib client/app/lib
git diff --numstat "$BASE"...HEAD -- client/module_core/test client/app/test
```

| Scope | Additions | Deletions |
| --- | ---: | ---: |
| Production/lib, including generated Freezed output | 499 | 573 |
| Tests, including the new matcher | 121 | 96 |

## Behavior

No user-visible, analytics, database, wire, or persisted behavior changed.
Composer availability, discovery-error precedence, send-time edit guards,
latest-configuration restoration, submission identity, staged commands, and
fast-new-session-launch restoration semantics remain unchanged.

## Verification

```bash
cd client/module_core && dart run build_runner build --delete-conflicting-outputs  # 0 outputs on final run
cd client/module_core && dart analyze --fatal-infos                                # clean
cd client/module_core && dart test test/cubits/new_session                         # 87 passing
cd client/app && flutter analyze --fatal-infos                                     # clean
cd client/app && flutter test test/features/new_session                            # 40 passing
git diff --check                                                                    # clean
```

The pinned formatter reported no changes in the six compatible handwritten
files and then hit its known Dart 3.13 enhanced-enum crash in
`remote_failure_reason.dart`. Both affected packages analyze cleanly, and the
generator is stable.

Architecture implementation review approved the composed state boundary and
cubit/UI integration with no findings. A separate correctness review found no
plausible regressions.
