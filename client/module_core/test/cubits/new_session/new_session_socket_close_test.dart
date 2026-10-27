import "dart:convert";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/client/relay_http_client.dart";
import "package:sesori_dart_core/src/api/filesystem_api.dart";
import "package:sesori_dart_core/src/api/plugin_api.dart";
import "package:sesori_dart_core/src/api/project_api.dart";
import "package:sesori_dart_core/src/api/session_api.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/cubits/new_session/new_session_cubit.dart";
import "package:sesori_dart_core/src/cubits/new_session/new_session_state.dart";
import "package:sesori_dart_core/src/repositories/plugin_repository.dart";
import "package:sesori_dart_core/src/repositories/project_repository.dart";
import "package:sesori_dart_core/src/repositories/session_repository.dart";
import "package:sesori_dart_core/src/services/new_session_options_service.dart";
import "package:sesori_dart_core/src/services/new_session_plugin_service.dart";
import "package:sesori_dart_core/src/services/new_session_selection_tracker.dart";
import "package:sesori_dart_core/src/services/session_launch_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fake_relay_bridge.dart";
import "../../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  test("a socket close under the options load and project check keeps both loading, with no Retry", () async {
    const plugin = PluginMetadata(
      id: "plugin-1",
      displayName: "Plugin One",
      isDefault: true,
      state: PluginLifecycleState.ready,
      actionHint: null,
    );
    final bridge = FakeRelayBridge(
      answer: (request) => switch (request.path) {
        "/plugin" => RelayResponse(
          id: request.id,
          status: 200,
          headers: const {},
          body: jsonEncode(
            const PluginListResponse(plugins: [plugin], bridgeId: "bridge-1", supportsSessionOptions: true).toJson(),
          ),
        ),
        _ => null,
      },
    );
    final connectionService = await bridge.connect();
    final client = RelayHttpApiClient(connectionService);
    final sessionRepository = SessionRepository(api: SessionApi(client: client));
    final pluginPreferenceRepository = MockPluginPreferenceRepository();
    when(
      () => pluginPreferenceRepository.readPluginId(bridgeId: any(named: "bridgeId")),
    ).thenAnswer((_) async => null);
    final selectionTracker = NewSessionSelectionTracker();
    final productAnalyticsService = stubbedProductAnalyticsService();
    final authSession = FakeAuthSession(initialState: const AuthState.initial());
    addTearDown(authSession.dispose);

    final loadsWaiting = bridge.unansweredRequests.take(2).map((request) => request.path).toList();
    final cubit = NewSessionCubit(
      connectionService: connectionService,
      newSessionPluginService: NewSessionPluginService(
        pluginRepository: PluginRepository(api: PluginApi(client: client)),
        pluginPreferenceRepository: pluginPreferenceRepository,
      ),
      newSessionOptionsService: NewSessionOptionsService(sessionRepository: sessionRepository),
      projectRepository: ProjectRepository(
        api: ProjectApi(client: client),
        filesystemApi: FilesystemApi(client: client),
        sessionApi: SessionApi(client: client),
      ),
      selectionTracker: selectionTracker,
      composerDraftRepository: inMemoryComposerDraftRepository(),
      productAnalyticsService: productAnalyticsService,
      sessionLaunchService: SessionLaunchService(
        sessionRepository: sessionRepository,
        launchRepository: inMemorySessionLaunchRepository(),
        feedbackPromptService: FakeFeedbackPromptService(),
        productAnalyticsService: productAnalyticsService,
        selectionTracker: selectionTracker,
        authSession: authSession,
      ),
      dedicatedWorktreePreferenceStore: FakeDedicatedWorktreePreferenceStore(),
      projectId: "project-1",
      projectName: null,
      projectKind: ProjectKind.folder,
    );
    addTearDown(cubit.close);
    final states = <NewSessionState>[];
    final stateSubscription = cubit.stream.listen(states.add);
    addTearDown(stateSubscription.cancel);
    expect(await loadsWaiting, unorderedEquals(["/session/options", "/project/current"]));
    final markerArrived = bridge.unansweredRequests.first;
    final marker = client.get("/marker", fromJson: (json) => json);
    await markerArrived;

    await bridge.closeSocket();
    // The close fails the marker together with both loads; the cubit then
    // takes their failures in.
    expect(await marker, isA<ErrorResponse<Map<String, dynamic>>>());
    await pumpEventQueue();
    expect(connectionService.currentStatus, isA<ConnectionReconnecting>());

    // Neither the options' Retry nor the "project cannot be checked" card
    // shows for a moment before the reconnect answers.
    final shown = states.map((state) => state.agentModelData).nonNulls;
    expect(shown.map((data) => data.optionsState), everyElement(isNot(isA<NewSessionOptionsFailureState>())));
    expect(
      shown.map((data) => data.projectWorktreeCapability),
      everyElement(isNot(NewSessionProjectWorktreeCapability.unavailable)),
    );
    expect(cubit.state.agentModelData?.optionsState, isA<NewSessionOptionsLoadingState>());
    expect(cubit.state.agentModelData?.projectWorktreeCapability, NewSessionProjectWorktreeCapability.loading);
    expect(cubit.state.phase, isA<NewSessionPhaseIdle>());
  });
}
