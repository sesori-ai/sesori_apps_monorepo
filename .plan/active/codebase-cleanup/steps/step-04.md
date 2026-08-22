# Step 4/45 — Tighten management fields and correct compatibility markers

**PR:** [#1022](https://github.com/sesori-ai/sesori_apps_monorepo/pull/1022)

## Re-verification against `main`

`plugin_management.dart` did not exist at tag `v1.6.0` and already carried both
fields at `v1.7.0`, so no public bridge emitted the response without them. The
management **route** itself first appears at `v1.7.0` and the client maps a 404
to `PluginManagementLoadResult.unsupported()`, so v1.4–v1.6 peers never decode
this payload.

Deferred: the `PluginAuthenticationChallengeType` enum beside the union key
(removing it would change generated JSON), and `GlobalSession`/`SessionProject`
— `sesori_plugin_opencode` already generates an equivalent model, so reuse
versus relocation belongs with Steps 25/26.

## Verification

Analyze clean in shared, all 12 bridge packages, all 7 client modules. Tests:
shared 358, `bridge/app` 2,693, opencode 434, acp 260, claude 253, codex 392,
pi 260, `module_core` 1,171, `client/app` 987.
