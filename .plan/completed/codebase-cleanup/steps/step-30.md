# Step 30 — Delete SessionService and inline thin services

The client retained service and repository pairs where the service either only
delegated or owned logic that belonged at an existing layer. This step removes
those extra seams and the dead state and helpers identified beside them.

## Re-verification against `main`

- `SessionService` had five production callers across `SessionListCubit` and
  `NewSessionCubit`; its remaining methods were unused pass-throughs. Model and
  command normalization were its only logic.
- `BridgeSettingsService` delegated three repository methods and parsed one
  bounded integer input for its sole cubit consumer.
- Session and project view declarations had parallel API and repository pairs
  over the same transport operation.
- The planned `ServerConnectionConfig.authToken` claim was partly stale: every
  caller can now pass it explicitly, but disconnected and test states genuinely
  use `null`. It is therefore `required String?`, not non-nullable.
- The planned dead app test helper reference was stale. The helper file is now
  160 lines, and its matching helper, `findBrandLogo`, has six callers, so
  nothing was deleted there.

## What changed

- Deleted `SessionService`; the two cubits now use `SessionRepository`, which
  owns model and command normalization at the request boundary.
- Deleted `BridgeSettingsService`; `BridgeSettingsCubit` calls the repository
  directly and consumes a typed update plan parsed by the repository-domain
  settings model.
- Replaced the session/project view API and repository twins with
  `ViewDeclarationApi` and `ViewDeclarationRepository`, and regenerated DI.
- Kept the cleanup rejection DTO private to the API boundary. The repository
  maps it to a domain rejection and retains the API exception as typed
  `innerError`; `SessionListCubit` no longer imports the API layer.
- Added `_withOwnedClaim` to remove the repeated project-view claim lookup and
  update sequence.
- Adopted `CompositeSubscription` in the session-detail, plugin-management,
  and diff cubits.
- Deleted the never-emitted stale-project state and UI, the HTTP method
  converter, write-only active-directory APIs, the unused bridge-connected
  load field, and the unused GoRouter navigation extension.
- Made `ServerConnectionConfig.authToken` required-but-nullable and updated all
  callers explicitly.

The implementation deletes 1,481 lines and adds 632 across production, tests,
and generated output. It exceeds the 1,500 changed-line soft cap only because
the step intentionally deletes several classes and their tests, regenerates DI
and Freezed output, and updates repository call expectations in lockstep.

## Behavior

No user-visible or database behavior changes. Requests still normalize model
IDs, model variants, and slash commands before reaching the API. View claims,
bridge-settings validation, cleanup rejection presentation, and subscription
disposal retain their prior semantics. No wire or persisted contract changed.

## Verification

```bash
cd client/module_core && dart run build_runner build --delete-conflicting-outputs
cd client/module_core && dart analyze --fatal-infos
cd client/module_core && dart test                                      # 1,288 passing
cd client/app && flutter analyze --fatal-infos
cd client/app && flutter test test/features/new_session test/features/session_list test/core/widgets  # 165 passing
cd client/module_desktop_core && dart analyze --fatal-infos
cd client/desktop && flutter analyze --fatal-infos
git diff --check
```

The pinned formatter formatted the compatible files, then hit its known
enhanced-enum crash in four cubit files. Both owning analyzers remain clean.

The required `architecture-implementation-review` skill was unavailable when
invoked. A scoped manual architecture review approved the dependency, DI,
boundary, and lifecycle changes with no blocking findings; formal architecture
review remains a human review focus on the PR.
