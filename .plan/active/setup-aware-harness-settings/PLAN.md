# Setup-Aware Harness Settings

## Status

- **Plan slug:** `setup-aware-harness-settings`
- **Parent plan:** `.plan/active/setup-aware-plugin-lifecycle`
- **Status:** ready for implementation; no Stage 13 implementation branch has
  started
- **Implementation base:** current `origin/main` after Stage 12 merge
  `6cedf5bd`, force-disable reconciliation `877f0b58`, and Cursor recency
  `ae060c5f`
- **Reference only:** frozen PR #511, substantive implementation commit
  `167a3ee7`, action-preservation follow-up `bc3918cb`, head `4f07172f`

This child plan owns the replacement delivery sequence for parent Stage 13. It
inherits the parent's locked product decisions and preserves current-main
behavior that frozen PR #511 predates. Frozen PR #511 is evidence, not
mergeable history: no replacement branch rebases, merges, or cherry-picks it.

## Goal

Deliver the mobile Harnesses settings surface and per-bridge harness preference
in eight independently reviewable PRs. Each slice compiles and verifies against
its base, exposes no placeholder user surface, and leaves no temporary public
contract that a later slice must break.

The user-facing destination is **Harnesses**. Internal bridge, shared, API,
repository, service, and cubit domain names remain `Plugin*`, matching the
existing plugin lifecycle architecture. Only routes, screens, localization, and
presentation-facing copy use Harnesses.

## Locked Boundaries

- Backend-specific behavior stays in its owning bridge plugin descriptor. Shared
  transport and clients consume backend-neutral contracts; Prego resolves an
  opaque presentation logo key without using plugin IDs as behavioral state.
- Lifecycle controls are capability-gated. In particular, OpenCode attach mode
  (`--opencode-no-auto-start`) is externally managed: Sesori must not offer or
  execute enable, disable, or restart for it. Clients never infer this from the
  plugin ID, runtime state, residency, or a non-positive timeout.
- Layering remains Foundation -> API -> Repository -> Service -> Consumer.
  Cubits never call APIs and are never registered in DI.
- Additive nullable wire fields must decode from older peers and must be omitted
  when null. Add dated compatibility comments where release-reader fallback is
  relevant.
- Current Stage 12 routes are final: `GET /plugin/management`,
  `POST /plugin/:id/command`, and `PATCH /plugin/idle-timeout`. Mutation
  responses return authoritative snapshots; `snapshotToken` is opaque and
  equality-only, never ordered.
- `ConnectionService.currentStatus`, `status`, `events`, and
  `dataMayBeStale` are all consumed. Refresh staleness is consumed only after a
  supported or unsupported snapshot applies; failed or connection-blocked
  refreshes preserve and re-arm staleness.
- Keep one open implementation PR and one local successor built from that PR's
  latest reviewed head. After a predecessor merges, merge updated `origin/main`
  into the successor, reverify, then open it. Never work farther than one slice
  ahead.
- Changed-line estimates include additions plus deletions against the PR base,
  including generated and mechanical lockstep output. Approximately 1,000
  changed lines is the reviewability target, not a hard numerical gate. A simple
  generated or mechanical excess must be named in the PR body; complex or
  stateful work splits earlier when useful.

## Delivery Sequence

| Step | Branch | Exact PR title | Estimate | Review boundary |
|---|---|---|---:|---|
| 1/7 | `setup-aware-harness-settings-preferences` | `[setup-aware-harness-settings] feat(client): remember harnesses per bridge [step 1/7]` | 650-750 | Per-bridge last-submitted harness selection. |
| 2/7 | `setup-aware-harness-settings-transport` | `[setup-aware-harness-settings] feat(client): add harness management transport [step 2/7]` | 300-400 | Management HTTP/repository typed results. |
| 3/7 | `setup-aware-harness-settings-service` | `[setup-aware-harness-settings] feat(client): synchronize harness management [step 3/7]` | 550-700 | Replay, coalescing, reconnect, and mutation fencing. |
| 4/7 | `setup-aware-harness-settings-branding` | `[setup-aware-harness-settings] feat(prego): render harness logos [step 4/7]` | 750-900 | Descriptor-to-Prego brand key flow plus chooser rendering. |
| 5/7 | `setup-aware-harness-settings-overview` | `[setup-aware-harness-settings] feat(app): add harness settings overview [step 5/7]` | 1,100-1,300 | Notifications-style read-only Harnesses page, final state contract, and settings entry. |
| 6/8 | `setup-aware-harness-settings-state` | `[setup-aware-harness-settings] feat(client): add harness management actions [step 6/8]` | 650-800 | Mutation cubit behavior over service-owned validation and force policy. |
| 7/8 | `setup-aware-harness-settings-capabilities` | `[setup-aware-harness-settings] feat(bridge): declare harness management capabilities [step 7/8]` | 650-850 | Backend-neutral capability declaration, transport, and authoritative bridge enforcement. |
| 8/8 | `setup-aware-harness-settings-controls` | `[setup-aware-harness-settings] feat(app): add harness management controls [step 8/8]` | 800-1,000 | Management controls page with capability-gated safe/force and timeout flows. |

Steps 2 and 3 are functionally independent from Step 1, but the series still
runs sequentially. Step 5 expects the Step 3 snapshot contract and the Step 4
logo primitive. The series expanded from seven to eight slices after Steps 1-5
merged, when product clarification required a cross-layer externally-managed
capability contract. Their historical `/7` PR title suffixes remain unchanged;
Steps 6-8 use the final `/8` total. Steps 6-8 complete the control surface; no
management mutation is exposed before Step 8.

## Step 1/7: Per-Bridge Harness Preference

### Scope

Add nullable `bridgeId` to `PluginListResponse` and regenerate shared output.
Missing or null values remain omitted from JSON.

Inject the existing `BridgeIdProvider` into `GetPluginsHandler`, pass the
current `Orchestrator`'s `_bridgeRegistrationService`, and include the current
bridge ID in `GET /plugin`. The fallback response constructed by
`PluginRepository` for older 404 discovery bridges sets `bridgeId: null` so
no preference is invented.

Add:

```dart
@lazySingleton
class PluginPreferenceApi {
  PluginPreferenceApi({required SecureStorage storage});

  Future<String?> readPluginId({required String bridgeId});
  Future<void> writePluginId({
    required String bridgeId,
    required String pluginId,
  });
}
```

The secure-storage key is
`new_session_plugin_${Uri.encodeComponent(bridgeId)}`. Auth server bridge IDs
are globally unique, so no account prefix is added. Revocation remints the ID
and intentionally starts a fresh preference; stale keys have no deletion API
because there is no concrete cleanup caller.

Add:

```dart
@lazySingleton
class PluginPreferenceRepository {
  PluginPreferenceRepository({required PluginPreferenceApi api});

  Future<String?> readPluginId({required String bridgeId});
  Future<void> writePluginId({
    required String bridgeId,
    required String pluginId,
  });
}
```

Add:

```dart
final class NewSessionPluginDiscovery {
  const NewSessionPluginDiscovery({
    required this.bridgeId,
    required this.plugins,
    required this.selected,
  });

  final String? bridgeId;
  final List<PluginMetadata> plugins;
  final PluginMetadata? selected;
}
```

```dart
@lazySingleton
class NewSessionPluginService {
  NewSessionPluginService({
    required PluginRepository pluginRepository,
    required PluginPreferenceRepository pluginPreferenceRepository,
  });

  Future<ApiResponse<NewSessionPluginDiscovery>> discover({
    required String? currentSelectedPluginId,
    required String? currentSelectionBridgeId,
  });

  Future<void> recordSelection({
    required String? bridgeId,
    required PluginMetadata plugin,
  });
}
```

`discover` preserves the existing success/failure `ApiResponse` contract and
owns the complete selection precedence. Current and saved selection candidates
are considered only when the response supplies a non-null bridge identity. The
current candidate must also originate from that same bridge identity; a screen
carried across bridge A -> bridge B cannot leak A's selection into B:

1. the current selection when its originating bridge ID equals the response
   bridge ID and its plugin ID still identifies a ready or degraded plugin;
2. the saved preference when its ID identifies a ready or degraded plugin and
   the response bridge ID is non-null;
3. the current bridge default.

When `bridgeId` is absent, the current bridge default wins immediately.

Missing, disabled, blocked, failed, unavailable, or unknown current/saved
plugins move to the next fallback. Secure-storage read failures are logged and
degrade to the default; write failures are logged and never block session
creation.

`NewSessionCubit` receives `NewSessionPluginService`, passes the current
selection plugin ID and the bridge ID that produced that selection into
discovery, and only maps the returned discovery result into composer state. It
carries the latest discovery bridge ID and, immediately before submitting
`createSession`, records the last submitted choice through explicit
fire-and-forget `unawaited(...)`. Do not use it as a last viewed/focused
selection.

Preserve current `DefaultModelSelector.pickFromProvider(defaultModelID:)`,
reconnect behavior, current plugin during refresh, staged command handling,
generation fencing, and all new-session state variants.

Production files:

- `shared/sesori_shared/lib/src/models/sesori/plugin_list_response.dart` and
  regenerated companions
- `bridge/app/lib/src/routing/get_plugins_handler.dart`
- `bridge/app/lib/src/bridge/orchestrator.dart`
- `client/module_core/lib/src/api/plugin_preference_api.dart`
- `client/module_core/lib/src/repositories/plugin_preference_repository.dart`
- `client/module_core/lib/src/services/new_session_plugin_service.dart`
- `client/module_core/lib/src/repositories/plugin_repository.dart` fallback
  constructor update
- `client/module_core/lib/src/cubits/new_session/new_session_cubit.dart`
- `client/module_core/lib/sesori_dart_core.dart`
- module-core DI source and regenerated `injection.config.dart`
- `client/app/lib/features/new_session/new_session_screen.dart`

### Verification

- Shared code generation, missing/null/omitted `bridgeId` contract tests, and
  `dart analyze --fatal-infos`.
- Focused bridge plugin-list handler and router construction tests, plus
  bridge-app fatal analysis.
- Preference API/repository/service tests for saved, default, unroutable,
  stale, storage-failure, missing-`bridgeId` default-only, and bridge
  identity-changing current-selection flows.
- Current new-session cubit and selection tests prove the service resolves
  current/saved/default precedence while the cubit only maps state, including
  `defaultModelID`, reconnect preservation, staged command, and last-submitted
  recording semantics.
- Focused mobile new-session tests; mobile and desktop fatal analysis.

## Step 2/7: Management Transport And Repository Results

### Scope

Add nullable `bridgeId` to shared `PluginManagementResponse` and regenerate its
companions. Compose the existing `BridgeRegistrationService` before
`PluginLifecycleService`, inject it through `BridgeIdProvider`, and have the
lifecycle service cache only private identity-free management state. It builds
the transport response when returning, requires the provider's current bridge
ID to be non-null, and fails closed before registration rather than publishing
an ambiguous modern snapshot or dispatching/persisting a mutation. The wire
field remains nullable only so newer
clients decode older Stage 12 bridges that omit it; null is omitted and receives
a dated compatibility comment. GET and mutation handlers remain pass-through
consumers of the same authoritative, identity-bearing service response shape.

Extend `PluginApi` using the current Stage 12 routes:

```dart
Future<ApiResponse<PluginManagementResponse>> getManagement();
Future<ApiResponse<PluginManagementResponse>> command({
  required String pluginId,
  required PluginLifecycleCommandRequest request,
});
Future<ApiResponse<PluginManagementResponse>> updateIdleTimeout({
  required PluginIdleTimeoutUpdateRequest request,
});
```

Request bodies serialize the shared Freezed request models; no inline JSON
maps.

Add handwritten internal result models, following
`SessionDetailLoadResult`'s pattern rather than adding roughly 500 generated
Freezed lines for two small internal families:

```dart
sealed class PluginManagementLoadResult {
  const PluginManagementLoadResult();

  const factory PluginManagementLoadResult.supported({
    required PluginManagementResponse response,
    required ApiError? refreshError,
  });
  const factory PluginManagementLoadResult.unsupported();
  const factory PluginManagementLoadResult.failure({required ApiError error});
}
```

A refresh failure after a supported snapshot is replayed as `supported` with
the retained response and a non-null `refreshError` only while the connected
bridge's authoritative response identity matches the retained snapshot. A bare
`failure` remains the initial load state or an unsupported-bridge request
failure. `ServerConnectionConfig` is not an identity key; the service scopes
snapshots by `PluginManagementResponse.bridgeId`, with `null` treated as one
legacy-peer identity bucket. A different non-null ID clears the retained
response and must never replay bridge A's management state while commands
route to bridge B.

```dart
sealed class PluginManagementMutationResult {
  const PluginManagementMutationResult();

  const factory PluginManagementMutationResult.success({
    required PluginManagementResponse response,
  });
  const factory PluginManagementMutationResult.notFound();
  const factory PluginManagementMutationResult.conflict({
    required PluginLifecycleConflict conflict,
  });
  const factory PluginManagementMutationResult.uncertain();
  const factory PluginManagementMutationResult.failure({required ApiError error});
}
```

Extend `PluginRepository`:

- `GET /plugin/management` 404 maps to `unsupported`; other errors map to
  explicit failure.
- Mutation 404 maps to `notFound`.
- HTTP 409 parses `PluginLifecycleConflict`; malformed 409 bodies map to
  explicit request failure rather than a partial conflict.
- Successful mutation bodies remain typed `PluginManagementResponse`.
- A 2xx mutation response whose body cannot be decoded maps to `uncertain`,
  not ordinary failure: the bridge may have committed the mutation, and a
  retryable-looking failure could execute it twice. The service schedules the
  authoritative GET required to learn the outcome.
- A bridge mutation that commits before its identity fence moves returns 503;
  the repository also maps that explicit post-commit response to `uncertain`.
- `uncertain` represents a mutation whose request was sent but whose outcome
  cannot be truthfully published because the response cannot prove it or the
  connection/service fence moved. Consumers render it as an uncertain state
  requiring refresh, never as a bridge rejection or a committed success.
- Existing discovery fallback behavior remains unchanged.

Export the new public result surface and regenerate module-core DI if the
repository/API registration graph changes. The management service and cubit do
not enter this slice.

Production files:

- `shared/sesori_shared/lib/src/models/sesori/plugin_management.dart` and
  regenerated companions
- `bridge/app/lib/src/bridge/runtime/bridge_runtime_runner.dart`
- `bridge/app/lib/src/services/plugin_lifecycle_service.dart`
- `client/module_core/lib/src/api/plugin_api.dart`
- `client/module_core/lib/src/repositories/models/plugin_management_result.dart`
- `client/module_core/lib/src/repositories/plugin_repository.dart`
- `client/module_core/lib/sesori_dart_core.dart`
- module-core DI source and regenerated `injection.config.dart` only when the
  actual registration graph changes

### Verification

- Shared code generation and missing/null/known/omitted `bridgeId` management
  compatibility tests.
- Focused bridge management handler identity tests.
- API method/path/body/typed-response tests for every route.
- Repository tests for supported, unsupported 404, mutation 404, typed 409,
  malformed 409, successful-status undecodable mutation body to `uncertain`,
  generic failure, and preserved discovery fallback.
- Module-core fatal analysis plus mobile and desktop fatal analysis.

## Step 3/7: Management Synchronization Service

### Scope

Add:

```dart
typedef _ManagementRequestFence = ({
  int connectionEpoch,
  int publicationGeneration,
  int staleGeneration,
  String? bridgeId,
});
```

```dart
@lazySingleton
class PluginManagementService with Disposable {
  PluginManagementService({
    required PluginRepository pluginRepository,
    required ConnectionService connectionService,
  });

  ValueStream<PluginManagementLoadResult> get snapshots;

  Future<void> refresh();

  Future<PluginManagementMutationResult> command({
    required String pluginId,
    required PluginLifecycleCommandRequest request,
  });

  Future<PluginManagementMutationResult> updateIdleTimeout({
    required PluginIdleTimeoutUpdateRequest request,
  });

  PluginManagementCommandPlan planApplyAllIdleTimeout({
    required String input,
  });

  PluginManagementCommandPlan planSetIdleTimeoutOverride({
    required String pluginId,
    required String input,
  });

  PluginManagementCommandPlan planClearIdleTimeoutOverride({
    required String pluginId,
  });

  PluginManagementForceAssessment assessForce({
    required PluginLifecycleConflict conflict,
    required PluginManagementForceAction action,
  });

  @override
  Future<void> onDispose();
}
```

The timeout and force return types are small handwritten Layer-3 models in the
service file, not wire DTOs:

```dart
sealed class PluginManagementCommandPlan {
  const PluginManagementCommandPlan();

  const factory PluginManagementCommandPlan.request({
    required PluginIdleTimeoutUpdateRequest request,
  });
  const factory PluginManagementCommandPlan.invalidInput();
}
```

```dart
enum PluginManagementForceAction { disable, restart }

sealed class PluginManagementForceAssessment {
  const PluginManagementForceAssessment();

  const factory PluginManagementForceAssessment.requiresConfirmation({
    required PluginLifecycleCommandRequest request,
  });
  const factory PluginManagementForceAssessment.notForceable();
}
```

Constructor behavior uses one initial-connect path because current
`ConnectionService.status` is replay-backed:

```text
read ConnectionService.currentStatus only to initialize the connection gate
   and connection epoch
subscribe ConnectionService.status
subscribe ConnectionService.events
subscribe ConnectionService.dataMayBeStale
let the replayed status event perform the initial connected transition once
```

Do not both act on `currentStatus` and process the replayed connected event as
a second trigger. Only `ConnectionConnected` permits management HTTP. Offline,
reconnecting, lost, and disconnected statuses reject or defer new attempts and
fence any in-flight attempt by connection epoch.

One private publication coordinator owns every snapshot application. A
connection-epoch or authoritative bridge-identity change immediately replaces
the replayed snapshot with a loading publication so late subscribers cannot
render facts from the prior bridge while the next authoritative GET is pending.
Both GET
and mutation completions capture `{connectionEpoch,
publicationGeneration, staleGeneration, bridgeId}` before their request and
revalidate that entire fence immediately before publishing. `bridgeId` comes
from the authoritative management response; the coordinator stores it with
each published snapshot. A response whose identity differs from the currently
published identity clears and replaces the retained snapshot; a response whose
identity differs from the captured request identity is fenced as superseded.
Any superseded publication generation means another local response has already
become newer; the older response must not publish, regardless of its opaque
token. The coordinator then preserves/re-arms staleness and schedules or awaits
one clean authoritative GET. Publication generation orders local client
publications only; it never orders bridge snapshots.

Refresh behavior:

- Refresh triggers increment a local stale generation.
- One coalesced refresh tail drains all triggers; no concurrent GETs.
- A supported or unsupported response applies only under the captured
  connection epoch, unsuperseded publication generation, and current disposal
  state.
- Only a successful supported/unsupported application consumes prior stale
  generations. Failure publishes `supported(refreshError:)` only when the
  retained supported snapshot's `bridgeId` still belongs to the active fenced
  identity; otherwise it publishes bare `failure` for the new bridge. Both
  paths preserve/re-arm staleness without polling.
- A trigger arriving while a GET is in flight schedules exactly one more drain.
- Incoming `SesoriPluginManagementChanged` with a non-null token equal to the
  current response token is ignored. Null or different tokens mark stale.
- `dataMayBeStale` always marks stale.

Mutation behavior:

- Typed non-success results return without publishing.
- If the connection epoch changed or the service is disposed, do not publish;
  retain staleness and return `PluginManagementMutationResult.uncertain`.
- If no snapshot was published since the captured fence, publish the returned
  response.
- If another snapshot published while the mutation was in flight, do not infer
  order from the opaque token or publish the returned body over newer local
  state. Mark stale, perform an authoritative GET, and return `uncertain` so
  the caller does not claim either committed success or bridge rejection.
- A successful mutation consumes only the staleness known at its captured
  fence; a trigger arriving during the mutation remains stale.
- `onDispose` cancels the connection subscriptions, awaits the active tail, and
  closes the replay subject.

Production files:

- `client/module_core/lib/src/services/plugin_management_service.dart`
- `client/module_core/lib/sesori_dart_core.dart`
- module-core DI source and regenerated `injection.config.dart`

### Verification

- Constructor replay for an already-connected service performs exactly one
  initial management GET.
- Initial connect, same-`bridgeId` reconnect, changed-`bridgeId` transition,
  legacy null-identity peer, bridge-offline transition, manual refresh,
  management SSE refresh, replay-loss refresh, equal-token suppression, and
  disposal.
- Two triggers while one GET runs produce one follow-up drain.
- Failed refresh preserves staleness; next success consumes it.
- Refresh-before-mutation, mutation-before-refresh, and refresh-after-refresh
  publication races all reject superseded responses.
- Disconnect during either request returns the required typed outcome without
  publication.
- An undecodable successful mutation response returns `uncertain` and schedules
  an authoritative GET without inviting an immediate duplicate retry.
- Mutation after an intervening publication triggers authoritative GET and
  returns `uncertain` rather than unordered publication.
- A failed first load after switching bridges never publishes the previous
  bridge's retained snapshot.
- Module-core focused tests and fatal analysis; mobile and desktop fatal
  analysis.

## Step 4/7: Backend-Neutral Harness Logos

### Scope

Use the existing generated Prego glyphs `VESPRSolid.opencode`,
`VESPRSolid.codex`, and `VESPRSolid.cursor`; do not add or edit icon font
assets or generated icon code.

Use the existing stable plugin ID as the presentation lookup key. Do not add a
second logo-key field to plugin descriptors, bridge registration metadata, or
shared wire contracts. Add the shared built-in `Harness` enum with `opencode`,
`codex`, and `cursor` values. Transport contracts continue carrying open
`String pluginId` values so a newer bridge can advertise an unknown harness to
an older app. Built-in producers and presentation comparisons use
`Harness.<value>.name`; unknown strings remain valid and render the generic
fallback.

Add a non-generated Prego primitive:

```dart
class PregoBrandLogo extends StatelessWidget {
  const PregoBrandLogo({
    super.key,
    required this.pluginId,
    this.size = 20,
    this.color,
  });

  final String pluginId;
  final double size;
  final Color? color;
}
```

Its private/static resolver maps exactly:

```text
"opencode" -> VESPRSolid.opencode
"codex"    -> VESPRSolid.codex
"cursor"   -> VESPRSolid.cursor
other      -> TablerRegular.plug
```

The logo is decorative; visible display-name text remains the accessible
identity signal. Never interpret the plugin ID as a URL, asset path, font
family, code point, capability, or behavior. Export the primitive from
`module_prego.dart`.

Update the existing new-session plugin chooser to render the ID-matched logo in
each option, retaining its current layout and Prego tokens. The Harnesses
screens consume the primitive in later slices.

Production files:

- `shared/sesori_shared/lib/src/models/sesori/plugin_identity.dart`
- OpenCode, Codex, and Cursor plugin identity producers
- Cursor and module_prego package dependency declarations
- `client/module_prego/lib/components/icons/prego_brand_logo.dart`
- `client/module_prego/lib/module_prego.dart`
- `client/app/lib/features/new_session/new_session_plugin_chooser.dart`

### Verification

- Shared and concrete-plugin tests preserve the three built-in string IDs.
- Prego widget tests for three mappings plus unknown-ID fallback.
- Existing chooser rendering tests.
- Focused tests and fatal analysis in shared, concrete plugin packages,
  module_prego, and mobile.

## Step 5/7: Harnesses Overview Page

### Scope

Add typed routes:

```dart
AppRouteDef.settingsHarnesses("/settings/harnesses")
const factory AppRoute.settingsHarnesses() = AppRouteSettingsHarnesses;
```

The route path is plural Harnesses even though domain models remain plugins.
Do not use `state.extra`.

Register the nested route under `/settings` beside the existing Notifications
and Profile routes. Desktop does not add a route or screen; desktop validation
is exhaustive compile compatibility only.

In `SettingsScreen`, the existing Notifications row stops being `isLast`. Add
the Harnesses row immediately below it in the same standalone grouped card:

```dart
PregoGroupedRow(
  icon: TablerRegular.bell,
  title: Text(loc.settingsNotificationsTitle),
  trailing: const Icon(TablerRegular.chevron_right),
  onTap: () => context.pushRoute(const AppRoute.settingsNotifications()),
),
PregoGroupedRow(
  icon: TablerRegular.plug,
  title: Text(loc.settingsHarnessesTitle),
  trailing: const Icon(TablerRegular.chevron_right),
  onTap: () => context.pushRoute(const AppRoute.settingsHarnesses()),
  isLast: true,
),
```

Preserve current Account, Appearance, Support, Legal, footer, external links,
and close behavior.

Add `HarnessesSettingsScreen`, modeled visually and structurally on
`NotificationSettingsScreen`:

```dart
class HarnessesSettingsScreen extends StatelessWidget {
  const HarnessesSettingsScreen({super.key});
}
```

Construct a `PluginManagementCubit` through `BlocProvider(create:)` using
`getIt<PluginManagementService>()`. This slice introduces the final
`PluginManagementState` contract and its generated companion; Step 6 extends
cubit behavior without replacing that state shape:

The Step 3 service file owns `PluginManagementForceAction`; this state imports
that Layer-3 domain enum rather than redefining it:

```dart
@Freezed()
sealed class PluginManagementActionError
    with _$PluginManagementActionError {
  const factory PluginManagementActionError.invalidIdleTimeout();
  const factory PluginManagementActionError.notFound();
  const factory PluginManagementActionError.conflict({
    required PluginLifecycleConflict conflict,
  });
  const factory PluginManagementActionError.uncertain();
  const factory PluginManagementActionError.request({
    required ApiError error,
  });
}
```

```dart
@Freezed()
sealed class PluginManagementRefreshState
    with _$PluginManagementRefreshState {
  const factory PluginManagementRefreshState.idle();
  const factory PluginManagementRefreshState.failed({
    required ApiError error,
  });
}

@Freezed()
sealed class PluginManagementActionTarget
    with _$PluginManagementActionTarget {
  const factory PluginManagementActionTarget.allHarnesses();
  const factory PluginManagementActionTarget.harness({
    required String pluginId,
  });
}

@Freezed()
sealed class PluginManagementActionState
    with _$PluginManagementActionState {
  const factory PluginManagementActionState.idle();
  const factory PluginManagementActionState.inProgress({
    required PluginManagementActionTarget target,
  });
  const factory PluginManagementActionState.failed({
    required PluginManagementActionTarget target,
    required PluginManagementActionError error,
  });
  const factory PluginManagementActionState.forceConfirmationRequired({
    required String pluginId,
    required PluginManagementForceAction action,
    required PluginLifecycleConflict conflict,
    required PluginLifecycleCommandRequest request,
  });
}

@Freezed()
sealed class PluginManagementState with _$PluginManagementState {
  const factory PluginManagementState.loading();
  const factory PluginManagementState.unsupported();
  const factory PluginManagementState.failure({required ApiError error});
  const factory PluginManagementState.ready({
    required PluginManagementResponse response,
    required PluginManagementRefreshState refresh,
    required PluginManagementActionState action,
  });
}
```

The Step 5 cubit subscribes to the Step 3 replay stream, exposes `refresh()` and
`dismissRefreshError()`, and emits ready with idle refresh/action variants.
Mutation methods and controls remain out of this slice. A later refresh failure
retains ready state with a dismissible failed refresh variant. The nested sealed
states keep refresh and action lifecycles independent without nullable
coordination fields or a combinatorial outer-state union.

The scaffold matches Notifications:

```dart
PregoGlassScaffold(
  title: loc.settingsHarnessesTitle,
  titleMode: PregoTopNavigationTitleMode.inline,
  banner: ConnectionBanner.maybeFor(context),
  actions: [close-to-projects action],
  onRefresh: cubit.refresh,
  slivers: [...],
)
```

Render through `SettingsSection`, `PregoGroupedRows`, `PregoGroupedRow`, and
Prego tokens only. The ready state contains one read-only card per harness:

- `PregoBrandLogo` in the leading slot.
- display name and Default badge.
- setup, runtime, work, and effective timeout rows.
- effective timeout values at or below zero render as `No timeout` with
  always-running guidance; they never render as zero minutes or claim to use
  the bridge default, because a resident harness may override the default
  operationally without a persisted per-harness timeout override.
- action hint/setup guidance when present.
- forward-compatible unknown setup/runtime/work values render readable copy
  and never crash.

There are no enable switches, mutation buttons, timeout dialogs, or force
confirmations in this slice. Loading uses the existing Prego loading treatment.
Unsupported explains that the connected bridge does not support Harnesses.
Initial failure provides Retry. A ready-page refresh failure appears as an
inline alert/error row while the last snapshot remains visible.

Add all user-facing copy to `app_en.arb` and regenerate localization. Text is
English-only for now.

Production files:

- `client/module_core/lib/src/routing/app_routes.dart`
- `client/module_core/lib/src/cubits/plugin_management/plugin_management_cubit.dart`
  for the read-only consumer defined in this slice; Step 6 extends behavior
  without replacing the state contract
- `client/module_core/lib/src/cubits/plugin_management/plugin_management_state.dart`
  and its regenerated Freezed companion
- `client/app/lib/core/routing/app_router.dart`
- `client/app/lib/features/settings/settings_screen.dart`
- `client/app/lib/features/settings/harnesses_settings_screen.dart`
- `client/app/lib/l10n/app_en.arb` and regenerated localization outputs
- route/cubit public exports as needed

### Verification

- Route encode/decode and router registration tests.
- Settings landing row placement and navigation, preserving every existing
  section.
- Harnesses loading, unsupported, initial failure/retry, ready, known-logo,
  generic-logo, default badge, and all setup/runtime/work unknown states.
- Pull/manual refresh and ready-state refresh failure retention.
- Close behavior and Notifications-style visual structure.
- Localization generation, focused module-core and Flutter tests, and fatal
  analysis in module_core, mobile, and desktop.

## Step 6/8: Management Cubit Actions

### Scope

Extend the read-only cubit introduced in Step 5 into the full mutation
consumer while retaining its final state contract:

```dart
class PluginManagementCubit extends Cubit<PluginManagementState> {
  PluginManagementCubit({required PluginManagementService service});

  Future<void> refresh();
  Future<void> enable({required String pluginId});
  Future<void> disable({required String pluginId});
  Future<void> restart({required String pluginId});
  Future<void> refreshSetup({required String pluginId});
  Future<void> applyIdleTimeoutToAll({required String input});
  Future<void> setIdleTimeoutOverride({
    required String pluginId,
    required String input,
  });
  Future<void> clearIdleTimeoutOverride({required String pluginId});
  Future<void> confirmForce();
  void dismissForceConfirmation();
  void dismissActionError();
  void dismissRefreshError();

  @override
  Future<void> close();
}
```

Command construction is exact:

- enable -> `PluginLifecycleCommandRequest.enable()`
- safe disable -> `PluginLifecycleCommandRequest.disable(mode: PluginStopMode.safe)`
- safe restart -> `PluginLifecycleCommandRequest.restart(mode: PluginStopMode.safe)`
- setup refresh -> `PluginLifecycleCommandRequest.refresh()`
- force disable/restart only from `confirmForce()`

Layer 3 owns domain input and policy. The cubit passes raw timeout text to the
specific `PluginManagementService.plan*` method for apply-all or per-harness
override and receives either a typed shared request or `invalidInput`. Clear
override is also planned by Layer 3 so the cubit does not assemble timeout
requests. Zero and negative integers are valid and match current resident
semantics; only a non-integer produces the invalid outcome. On a typed
conflict, the cubit passes the conflict and attempted action to
`PluginManagementService.assessForce`, which owns the forceability
classification:

- Empty reason lists are not forceable.
- Every reason must be one of `inFlight`, `busy`, or `workStateUnknown` to
  offer force.
- `transitioning`, `notEnabled`, or current-main `unknown` makes the conflict
  non-forceable.
- Force is one explicit second user action. It is never retried automatically.
- The bridge remains authoritative; a force request can still return conflict,
  not-found, uncertain, or failure.

The cubit maps service outcomes into the Step 5 state, emits loading/action
state, and stores the service-returned force request when confirmation is
required. It consumes only service-published snapshots, never emits a mutation
response independently, and never compares opaque tokens. It preserves an
in-progress action and pending force confirmation across incoming snapshots,
preserves ready state during a concurrent refresh failure, and clears action
errors only on explicit dismissal, completed action, or a deliberate state
transition. Every async gap checks `isClosed` before emitting.

Production files:

- `client/module_core/lib/src/services/plugin_management_service.dart` for the
  handwritten timeout-plan and force-assessment models plus service methods
- `client/module_core/lib/src/cubits/plugin_management/plugin_management_cubit.dart`
- module-core test helpers and public exports as needed
- no state source or generated state companion changes unless implementation
  proves the Step 5 contract itself is wrong

### Verification

- Service tests cover every timeout plan and force-assessment variant.
- Cubit tests cover every command and timeout request variant through the
  service-owned plans.
- Valid integer, zero, negative, whitespace, and invalid timeout input.
- Safe-first behavior and exactly one explicit force retry.
- Forceable and each non-forceable conflict reason, including unknown.
- Uncertain mutation maps to its explicit presentation error without claiming
  success or bridge rejection.
- In-flight action plus successful refresh.
- In-flight action plus failed refresh.
- Pending force confirmation plus refresh.
- Close during asynchronous action and refresh.
- Focused service/cubit tests, module-core fatal analysis, and mobile/desktop
  fatal analysis.

## Step 7/8: Management Capability Contract And Enforcement

### Scope

First add the backend-neutral management capability contract needed by the
controls. `PluginManagementMetadata` carries a closed set of independently
supported operations rather than an OpenCode-specific flag:

```dart
enum PluginManagementCapability {
  lifecycle,
  setupRefresh,
  idleTimeout,
  unknown,
}
```

The transport field is required and has no default. This capability contract and
its controls ship together before either exists in production, so there is no
released peer payload to preserve between internal implementation slices.
Unknown enum values degrade as unsupported. Do not infer capability from
`idleTimeoutMins <= 0`: that value also truthfully represents a managed plugin
configured never to idle.

The plugin interface independently defines its Layer-0 enum and descriptor
method; it never imports `sesori_shared`:

```dart
enum PluginControlCapability { lifecycle, setupRefresh, idleTimeout }

Set<PluginControlCapability> managementCapabilities({
  required PluginConfig config,
});
```

The wire-facing `PluginManagementCapability` remains independently defined in
`sesori_shared`. Existing descriptors default to all three interface
capabilities. The OpenCode descriptor omits lifecycle and idle-timeout
capabilities in no-auto-start attach mode while retaining setup refresh.
`bridge/app` maps the interface enum to the shared enum during composition and
publication; neither Layer-0 package depends on the other. The bridge remains
authoritative:

- enable, disable, and restart reject plugins without `lifecycle` support;
- setup refresh rejects plugins without `setupRefresh` support;
- per-plugin timeout set/clear rejects plugins without `idleTimeout` support;
- automatic idle suspension requires both `lifecycle` and `idleTimeout`
  support, checked before scheduling and again before stopping;
- apply-all updates the bridge default and only clears/applies per-plugin
  timeout state for capable plugins;
- unsupported operations return a typed non-forceable conflict and never touch
  process state or persisted per-plugin settings.

Production files:

- `shared/sesori_shared/lib/src/models/sesori/plugin_management.dart` and
  generated companions for the additive wire capability contract
- `bridge/sesori_plugin_interface/` for the independent descriptor capability
  enum and declaration
- registered plugin descriptors and `bridge/app` composition mapping
- `bridge/app/lib/src/services/plugin_lifecycle_service.dart` for authoritative
  capability publication and command/settings enforcement

### Verification

- Shared JSON covers declared capabilities, unknown values, and rejection of a
  missing required capability field.
- Interface tests cover the default declaration without importing shared; each
  concrete descriptor is updated in lockstep.
- Descriptor and bridge-service tests prove no-auto-start OpenCode publishes no
  lifecycle/timeout capability, setup refresh remains explicit, unsupported
  commands never touch runtime state, and unsupported timeout writes never
  mutate settings.
- Managed plugins retain every existing command and timeout flow; apply-all
  skips externally managed harness settings while updating the bridge default.

## Step 8/8: Harness Management Controls Page

### Scope

Step 8 renders only controls declared by the snapshot. An externally managed
harness remains visible with setup/runtime/work context and copy explaining that
its process is managed outside Sesori. Setup refresh remains available when its
separate capability is declared. No client layer recognizes OpenCode or
`no-auto-start`.

Add the second typed route:

```dart
AppRouteDef.settingsHarnessManagement("/settings/harnesses/manage")
const factory AppRoute.settingsHarnessManagement() =
    AppRouteSettingsHarnessManagement;
```

Register it as another nested settings route. Add a management navigation row
to the ready Harnesses overview:

```dart
PregoGroupedRow(
  icon: TablerRegular.settings,
  title: Text(loc.settingsHarnessManagementTitle),
  trailing: const Icon(TablerRegular.chevron_right),
  onTap: () =>
      context.pushRoute(const AppRoute.settingsHarnessManagement()),
  isLast: true,
)
```

Add:

```dart
class HarnessManagementScreen extends StatelessWidget {
  const HarnessManagementScreen({super.key});
}
```

It creates its own `PluginManagementCubit` over the singleton
`PluginManagementService`; replay supplies the current snapshot, so no state
passes through `GoRouter.extra`.

Use a back-leading scaffold that returns to the Harnesses overview and retains
the close-to-projects action:

```dart
PregoGlassScaffold(
  title: loc.settingsHarnessManagementTitle,
  titleMode: PregoTopNavigationTitleMode.backLeading,
  banner: ConnectionBanner.maybeFor(context),
  onBack: () => context.pop(),
  actions: [close-to-projects action],
  onRefresh: cubit.refresh,
  slivers: [...],
)
```

Render all controls with the same grouped settings language:

- Global idle timeout row and apply-all edit dialog.
- Per-harness enable/disable switch.
- Setup refresh action.
- Safe restart action.
- Per-harness timeout override dialog and clear-override row.
- `PregoBrandLogo` and display name on each harness card.
- Setup/runtime/work status remains visible for context.
- Disable conflicting controls while an action is in progress.
- Unsupported, initial failure, loading, and ready-refresh-error states use the
  same treatment as the overview.

Force confirmation:

- Trigger only when cubit state exposes an allowed pending disable/restart.
- Explicitly state that active work may be interrupted. Current main's #576
  reconciles sessions after forced disable, but the warning remains required.
- Cancel dismisses the pending confirmation and returns the action lifecycle to
  idle without sending a force request.
- Confirm sends exactly one force command and never schedules a retry.

Add remaining user-facing copy to `app_en.arb` and regenerate localization.

Production files:

- `client/module_core/lib/src/routing/app_routes.dart`
- `client/app/lib/core/routing/app_router.dart`
- `client/app/lib/features/settings/harnesses_settings_screen.dart`
- `client/app/lib/features/settings/harness_management_screen.dart`
- `client/app/lib/l10n/app_en.arb` and regenerated localization outputs

### Verification

- Mobile tests prove controls follow capabilities and never infer external
  management from plugin identity, runtime state, residency, or timeout value.

- Route encode/decode, router registration, overview-to-management navigation,
  back, and close behavior.
- Every loading/unsupported/failure/ready state.
- Global and per-harness timeout dialogs, including zero/negative/invalid
  input.
- Safe enable/disable/restart/setup-refresh interactions and control
  disabling while actions run.
- Conflict message, force confirmation cancel/confirm, and one-shot force
  behavior.
- Refresh failure while an action or force confirmation is pending.
- Known and generic logos in control cards.
- Localization generation, focused Flutter tests, module-core routing/cubit
  tests, and mobile/desktop fatal analysis.

## Risks And Compatibility

| Area | Required treatment |
|---|---|
| Older bridge discovery | Missing `bridgeId` decodes null and disables preference persistence without failing sessions. |
| Older clients | Additive `bridgeId` and `brandLogoKey` are ignored. |
| Newer bridge logos | Unknown or null logo keys render the generic plug and visible display name. |
| Logo trust boundary | `brandLogoKey` chooses bundled glyphs only; it is never a URL, path, font, or code execution input. |
| Management 404 | Maps to an explicit unsupported page, not a fatal connection error. |
| Snapshot ordering | Opaque tokens use equality only. Local connection/publication generations fence races. |
| Lost SSE replay | `dataMayBeStale` always triggers management refresh. |
| Preference timing | Persist the last submitted choice immediately before create-session request; creation failure does not roll it back. |
| Stale preference | A saved unroutable plugin falls back to the current bridge default. |
| Secure-storage failure | Log and degrade to default; never block new-session creation. |
| Safe/force | Safe first, explicit one-shot force, and unknown/non-forceable reasons never show force. |
| Current new-session behavior | Preserve Cursor `defaultModelID`, reconnect, staged command, and generation fencing. |
| Current settings design | Preserve Account, Notifications, Appearance, Support, Legal, and footer composition. |
| Generated files | Regenerate from source; never port generated output from frozen #511. |
| Desktop | No desktop Harnesses route/screen; validate shared exhaustive contracts and fatal analysis only. |

## Review And Verification Gates

- Every architecture-bearing implementation slice receives one Aristotle
  implementation review after relevant local verification and before delivery.
- Run code generation only from source models.
- Run focused tests named in each slice and fatal analysis in every changed
  package plus required downstream consumers.
- Do not rerun unchanged passing commands; CI supplies the full repository
  matrix after each PR opens.
- `git diff --check` must pass before every PR opens.

## Real Simulator E2E

Use the available iOS simulator with the PR build and the source bridge from
this repository. Launch the bridge with
`--data-dir ~/.local/share/sesori-dev` so it reuses the existing login and
development bridge data, and use the existing `random stuff` project for
session interactions.

Before launching the E2E bridge, preflight the host for other Sesori bridge
processes. Single-live-bridge replacement is not an acceptable implicit side
effect: stop or wait out any unrelated bridge deliberately and record what was
running so it can be restored afterward. Before mutations, snapshot the
development data's plugin settings, secure preferences that this slice writes,
and relevant `random stuff` session/catalog state. Restore those snapshots and
clean up test sessions after verification; mandatory E2E must not leave
persisted disable/timeout/preference/session state altered.

| Gate | Required coverage |
|---|---|
| After Step 1/7 | Connect through the normal app flow, open `random stuff`, verify each per-bridge harness choice persists across app reopen and falls back after a saved harness becomes unavailable. Restore the written preference afterward. Keep the omitted-`bridgeId` case in wire/service contract tests unless a real older-peer fixture is explicitly available; this repository's Step 1 bridge always emits the ID, so it cannot honestly exercise that path. |
| After Step 5/7 | Explicitly resolve the Step 3 service through the app's integration path, then verify initial snapshot load, reconnect/replay-loss refresh, management SSE invalidation, and identity-scoped retained snapshots against the real bridge. Open Settings, verify the Harnesses row is immediately below Notifications with the same grouped-row style, open the page, and verify logos, statuses, default badge, refresh, retained snapshot after refresh failure, unsupported state if an older bridge is available, and Notifications-style close behavior. |
| After Step 4/7 | Verify the new-session chooser renders the real OpenCode, Codex, and Cursor logos. Keep generic-logo verification in widget/contract tests unless an integration fixture can honestly return a null or unknown key; the normal three-descriptor bridge cannot produce that case. |
| After Step 8/8 | In `random stuff`, exercise safe enable/disable/restart/setup-refresh, busy-conflict copy, explicit force confirmation, timeout apply-all/override/clear, persistence across bridge restart, and session creation from the resulting harness state. Run OpenCode once in no-auto-start attach mode and verify lifecycle/timeout controls are absent while declared setup refresh remains available. Verify current-main forced-disable session reconciliation remains visible, then restore the pre-E2E durable state. |

Stop the temporary E2E bridge after verification and restore any deliberately
stopped pre-existing bridge. Do not kill an unrelated user bridge; identify
and handle every bridge process before startup, not only after testing.

## Completion

Stage 13 completes after all seven PRs merge, the Harnesses entry and two
pages are verified against a real bridge and simulator in `random stuff`,
frozen PR #511 is closed as superseded, and the parent tracker records merge
commits and verification.
