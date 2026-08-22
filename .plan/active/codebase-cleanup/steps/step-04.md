# Step 4/45 — Tighten management fields and correct compatibility markers

## Re-verification against `main`

`plugin_management.dart` did not exist at tag `v1.6.0` and already carried both
fields at `v1.7.0`, so no public bridge ever emitted the response without them.
The management **route** itself first appears at `v1.7.0`, and the client maps a
404 to `PluginManagementLoadResult.unsupported()`, so v1.4–v1.6 peers never
decode this payload at all.

Deferred from the plan: the `PluginAuthenticationChallengeType` enum beside the
union key (removing it would change generated JSON, so it needs its own
verification), and `GlobalSession`/`SessionProject` — `sesori_plugin_opencode`
already generates an equivalent `models/openapi/global_session.g.dart`, so
choosing between reuse and relocation belongs with Steps 25/26. The client keeps
its nullable `_activeBridgeId` fence: that tracks "identity not yet loaded",
which is client state, not the wire field.

COMPATIBILITY relabelling was checked against the tag, not the version-bump
commit: tag `v1.8.0` is `f89499f19` (2026-08-20), annotated "Submitted
production build 619", and every relabelled field is present in that tree.

## Verification

`dart analyze --fatal-infos` clean in `shared/sesori_shared`, all 12 bridge
packages, and all 7 client modules. `dart test`: shared 358, `bridge/app` 2,693,
opencode 434, acp 260, claude 253, codex 392, pi 260, `client/module_core`
1,171, `client/app` 987.

Architecture implementation review not run — field nullability and
parameter-shape changes inside existing models, no new or moved class, no DI
change, no route or payload-key change.
