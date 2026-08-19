import "dart:async";

import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/runtime/plugin_runtime.dart";
import "package:sesori_bridge/src/bridge/services/session_options_service.dart";
import "package:sesori_bridge/src/listeners/session_options_changed_refresh_listener.dart";
import "package:sesori_bridge/src/listeners/session_options_creation_refresh_listener.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("SessionOptionsCreationRefreshListener", () {
    late StreamController<SessionBindingsCommitted> source;
    late _FakeSessionOptionsService service;
    late SessionOptionsCreationRefreshListener listener;

    setUp(() {
      source = StreamController<SessionBindingsCommitted>.broadcast(sync: true);
      service = _FakeSessionOptionsService();
      listener = SessionOptionsCreationRefreshListener(source: source.stream, service: service)..start();
    });

    tearDown(() async {
      await listener.dispose();
      await source.close();
    });

    test("refreshes only session-creation commits with stable project attribution", () async {
      source.add(_commit(kind: SessionBindingCommitKind.catalogSync, projectId: "catalog-project"));
      source.add(_commit(kind: SessionBindingCommitKind.sessionCreation, projectId: "stable-project"));
      await _flushEvents();

      expect(service.creationCalls, [
        (pluginId: "plugin", projectId: "stable-project", generation: 7),
      ]);
      expect(service.successfulCreationProjects, ["stable-project"]);
    });

    test("passes stale generations to the service fence without refreshing", () async {
      service.currentGeneration = 8;

      source.add(_commit(kind: SessionBindingCommitKind.sessionCreation, projectId: "stale-project"));
      await _flushEvents();

      expect(service.creationCalls.single.generation, 7);
      expect(service.successfulCreationProjects, isEmpty);
    });

    test("contains an async refresh error and continues listening", () async {
      service.failingCreationProjects.add("fails");

      source.add(_commit(kind: SessionBindingCommitKind.sessionCreation, projectId: "fails"));
      source.add(_commit(kind: SessionBindingCommitKind.sessionCreation, projectId: "continues"));
      await _flushEvents();

      expect(service.creationCalls.map((call) => call.projectId), ["fails", "continues"]);
      expect(service.successfulCreationProjects, ["continues"]);
    });
  });

  group("SessionOptionsChangedRefreshListener", () {
    late _FakePluginRuntime runtime;
    late _FakeSessionOptionsService service;
    late SessionOptionsChangedRefreshListener listener;

    setUp(() {
      runtime = _FakePluginRuntime();
      service = _FakeSessionOptionsService();
      listener = SessionOptionsChangedRefreshListener(runtime: runtime, service: service)..start();
    });

    tearDown(() async {
      await listener.dispose();
      await runtime.closeEvents();
    });

    test("ignores generic and stale events and refreshes a current options change", () async {
      service.boundBackendSessionIds.add("current-session");

      runtime.emit(event: const BridgeSseVcsBranchUpdated(), generation: 7);
      runtime.emit(event: const BridgeSseSessionOptionsChanged(sessionID: "stale-session"), generation: 6);
      runtime.emit(event: const BridgeSseSessionOptionsChanged(sessionID: "current-session"), generation: 7);
      await _flushEvents();

      expect(runtime.generationChecks, [
        (pluginId: "plugin", generation: 6),
        (pluginId: "plugin", generation: 7),
      ]);
      expect(service.backendCalls, [
        (pluginId: "plugin", backendSessionId: "current-session", generation: 7),
      ]);
      expect(service.successfulBackendSessions, ["current-session"]);
    });

    test("pre-binding options changes no-op without preventing a later refresh", () async {
      runtime.emit(event: const BridgeSseSessionOptionsChanged(sessionID: "new-session"), generation: 7);
      await _flushEvents();

      expect(service.backendCalls, hasLength(1));
      expect(service.successfulBackendSessions, isEmpty);

      service.boundBackendSessionIds.add("new-session");
      runtime.emit(event: const BridgeSseSessionOptionsChanged(sessionID: "new-session"), generation: 7);
      await _flushEvents();

      expect(service.backendCalls, hasLength(2));
      expect(service.successfulBackendSessions, ["new-session"]);
    });

    test("contains source and async refresh errors and continues listening", () async {
      service
        ..boundBackendSessionIds.addAll(["fails", "continues"])
        ..failingBackendSessionIds.add("fails");

      runtime.addError(StateError("source failed"));
      runtime.emit(event: const BridgeSseSessionOptionsChanged(sessionID: "fails"), generation: 7);
      runtime.emit(event: const BridgeSseSessionOptionsChanged(sessionID: "continues"), generation: 7);
      await _flushEvents();

      expect(service.backendCalls.map((call) => call.backendSessionId), ["fails", "continues"]);
      expect(service.successfulBackendSessions, ["continues"]);
    });

    test("dispose cancels its runtime subscription", () async {
      await listener.dispose();

      runtime.emit(event: const BridgeSseSessionOptionsChanged(sessionID: "after-dispose"), generation: 7);
      await _flushEvents();

      expect(service.backendCalls, isEmpty);
    });
  });
}

SessionBindingsCommitted _commit({
  required SessionBindingCommitKind kind,
  required String projectId,
}) {
  return (
    pluginId: "plugin",
    projectId: projectId,
    generation: 7,
    kind: kind,
    backendSessionIds: const ["backend-session"],
  );
}

Future<void> _flushEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

const _optionsResponse = SessionOptionsResponse(
  agents: Agents(agents: []),
  providers: ProviderListResponse(items: [], connectedOnly: true),
  commands: CommandListResponse(items: []),
);

class _FakeSessionOptionsService() implements SessionOptionsService {
  int currentGeneration = 7;
  final Set<String> boundBackendSessionIds = {};
  final Set<String> failingCreationProjects = {};
  final Set<String> failingBackendSessionIds = {};
  final List<({String pluginId, String projectId, int generation})> creationCalls = [];
  final List<({String pluginId, String backendSessionId, int generation})> backendCalls = [];
  final List<String> successfulCreationProjects = [];
  final List<String> successfulBackendSessions = [];

  @override
  Future<SessionOptionsOutcome> loadDynamic({required String pluginId, required String projectId}) async {
    return const SessionOptionsCacheUnavailable();
  }

  @override
  Future<SessionOptionsOutcome> refreshActiveOnly({
    required String pluginId,
    required String projectId,
    required int generation,
  }) async {
    creationCalls.add((pluginId: pluginId, projectId: projectId, generation: generation));
    if (failingCreationProjects.contains(projectId)) throw StateError("creation refresh failed");
    if (generation != currentGeneration) return const SessionOptionsAutomaticNoOp();
    successfulCreationProjects.add(projectId);
    return const SessionOptionsAvailable(response: _optionsResponse);
  }

  @override
  Future<SessionOptionsOutcome> refreshActiveOnlyForBackendSession({
    required String pluginId,
    required String backendSessionId,
    required int generation,
  }) async {
    backendCalls.add((pluginId: pluginId, backendSessionId: backendSessionId, generation: generation));
    if (failingBackendSessionIds.contains(backendSessionId)) throw StateError("event refresh failed");
    if (generation != currentGeneration || !boundBackendSessionIds.contains(backendSessionId)) {
      return const SessionOptionsAutomaticNoOp();
    }
    successfulBackendSessions.add(backendSessionId);
    return const SessionOptionsAvailable(response: _optionsResponse);
  }

  @override
  Future<SessionOptionsOutcome> loadCacheOnly({required String pluginId, required String projectId}) async {
    return const SessionOptionsCacheUnavailable();
  }

  @override
  Future<SessionOptionsOutcome> refreshExplicit({required String pluginId, required String projectId}) async {
    return const SessionOptionsRefreshFailedUnavailable(
      failure: SessionOptionsKnownRefreshFailure(),
    );
  }

  @override
  Future<void> invalidateRejectedSelection({
    required String pluginId,
    required String projectId,
  }) async {}
}

class _FakePluginRuntime() implements PluginRuntime {
  final StreamController<SourcedPluginRuntimeEvent> _events = StreamController.broadcast(sync: true);
  final List<({String pluginId, int generation})> generationChecks = [];

  @override
  Stream<SourcedPluginRuntimeEvent> get backendEvents => _events.stream;

  @override
  bool isCurrentGeneration({required String pluginId, required int generation}) {
    generationChecks.add((pluginId: pluginId, generation: generation));
    return pluginId == "plugin" && generation == 7;
  }

  void emit({required BridgeSseEvent event, required int generation}) {
    _events.add((
      pluginId: "plugin",
      generation: generation,
      event: event,
      allowDuringStop: false,
      terminalHandoffConsumed: null,
    ));
  }

  void addError(Object error) => _events.addError(error, StackTrace.current);

  Future<void> closeEvents() => _events.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
