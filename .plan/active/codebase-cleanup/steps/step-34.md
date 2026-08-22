# Step 34 — Unify the plugin-management result and failure types

Plugin authentication start and cancel fail in exactly the same five ways, and
every layer spelled those five ways out twice: once for start, once for cancel.

## Re-verification against `main`

| Duplication | Where | Copies |
| --- | --- | --- |
| Five failure variants per result type | `plugin_management_result.dart:65-121` | 2 |
| Error → result classification | `plugin_repository.dart:35-64` | 2 |
| 409 conflict body → result | `plugin_repository.dart:66-87` | 2 |
| Failure → presentation error (5 arms) | `plugin_management_cubit.dart:68-91,158-185` | 2 |
| Mutation result → action state (5 arms) | `plugin_management_cubit.dart:276-323,342-360` | 2 |

The plan also claimed `_onConnectionStatus` has identical bodies in both
branches of `_receivedInitialStatus`. Confirmed: the two branches were
character-identical, so the flag decided nothing.

## What changed

- **One `PluginAuthenticationFailure`** (`notFound | conflict | unsupported |
  uncertain | request`) shared by both results, which collapse to
  `StartChallenge | StartFailed` and `CancelSuccess | CancelFailed`.
  Twelve variant classes become nine, and every layer stops writing the same
  five-way mapping twice.
- **One repository mapper.** `_mapAuthenticationFailure` classifies the
  `ApiError` once, and `_mapAuthenticationConflict` parses the 409 body once.
  The classification switch is now exhaustive over `ApiError`'s six variants
  rather than ending in a wildcard.
- **One cubit `_presentationErrorFor`**, and one `_actionStateFor` for the
  mutation→action mapping shared by `_runCommand` and `_runTimeoutPlan`.
- **`_receivedInitialStatus` deleted** along with its duplicated branch.

Measured with `git diff --numstat origin/main...HEAD`:

| Scope | Files | Added | Deleted | Changed | Net |
| --- | ---: | ---: | ---: | ---: | ---: |
| `client/module_core/lib` | 4 | 170 | 208 | 378 | **-38** |
| tests (`module_core` + `app`) | 4 | 42 | 12 | 54 | +30 |
| all code | 8 | 212 | 220 | 432 | -8 |

Per lib file: cubit `+94 -115`, result models `+43 -36`, repository `+24 -34`,
service `+9 -23`.

The net is small because the win is structural — 378 changed lines in `lib` to
remove five duplicated mappings, not bulk deletion. Tests grow by 30 lines
because variant-class assertions became nested matchers that still pin the exact
failure (see Verification).

## Behavior preserved deliberately

Two places would have been wrong under a naive "share everything" collapse, and
each keeps its own arm:

- **An uncertain *cancel* is not a failure.** It emits
  `PluginAuthenticationPresentationState.cancellingUncertain`, keeping the
  challenge on screen, because the cancel may still have landed. Only the other
  four failures go through `_presentationErrorFor`.
- **An uncertain *start* keeps the plugin tracked** in
  `PluginManagementService`, so a pending outcome can still settle it, while
  every other start failure calls `_forgetAuthentication`.

Both are now single pattern-matched arms (`…Failed(failure:
PluginAuthenticationFailureUncertain())`) rather than separate variant classes.

`_runTimeoutPlan` passes `force: null` because an idle-timeout update offers no
force retry — previously that was expressed by simply not writing the force
branch, and is now explicit.

## A note on the force context

`_actionStateFor` needs both a plugin id and a force action to build
`forceConfirmationRequired`, and needs neither when the caller offers no force
retry. Rather than two nullable coordination parameters, they travel as one
nullable `_ForceContext`, so a force action cannot go missing its plugin id.

## Verification

```bash
cd client/module_core && dart analyze --fatal-infos && dart test  # 1,171 passing
cd client/app        && dart analyze --fatal-infos
cd client/app        && flutter test test/features/settings       # 64 passing
```

Test assertions moved from variant-class checks (`isA<PluginAuthenticationStartUnsupported>()`)
to nested matchers on the shared failure
(`isA<PluginAuthenticationStartFailed>().having((r) => r.failure, "failure", isA<PluginAuthenticationFailureUnsupported>())`),
so they still pin the exact failure rather than just "some failure".

Architecture implementation review: not run. No new layer, DI change, or wire
contract — this merges two parallel sealed hierarchies inside one package and
deduplicates their mappers.

## Not done here

The plan's optional item — giving `PluginAuthenticationPresentationState`'s four
variants a shared `{pluginId, verificationUri, userCode}` record — is left for
Step 38, which owns the shell's sealed→bools flattening in
`harnesses_settings_screen.dart` and will change the same states.
