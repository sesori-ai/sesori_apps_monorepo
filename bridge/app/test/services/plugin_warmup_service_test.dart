import "dart:async";

import "package:sesori_bridge/src/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/runtime/plugin_runtime.dart";
import "package:sesori_bridge/src/services/plugin_warmup_service.dart";
import "package:sesori_bridge/src/services/plugin_warmup_settings_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("does nothing while session-open warm-up is disabled", () async {
    final sessionRepository = _FakeSessionRepository();
    final pluginRuntime = _FakePluginRuntime();
    final settingsService = _FakePluginWarmupSettingsService(enabled: false);
    final service = PluginWarmupService(
      sessionRepository: sessionRepository,
      pluginRuntime: pluginRuntime,
      settingsService: settingsService,
    );

    await service.warmForSession(sessionId: "session-one");

    expect(sessionRepository.lookups, isEmpty);
    expect(pluginRuntime.startedPluginIds, isEmpty);
  });

  test("starts the plugin owning the viewed session", () async {
    final sessionRepository = _FakeSessionRepository(
      lookup: ({required sessionId}) async => _storedSession(id: sessionId),
    );
    final pluginRuntime = _FakePluginRuntime();
    final service = PluginWarmupService(
      sessionRepository: sessionRepository,
      pluginRuntime: pluginRuntime,
      settingsService: _FakePluginWarmupSettingsService(enabled: true),
    );

    await service.warmForSession(sessionId: "session-one");

    expect(pluginRuntime.startedPluginIds, ["opencode"]);
  });

  test("a disable committed during lookup prevents the pending start", () async {
    final pluginLookup = Completer<StoredSession?>();
    final sessionRepository = _FakeSessionRepository(
      lookup: ({required sessionId}) => pluginLookup.future,
    );
    final pluginRuntime = _FakePluginRuntime();
    final settingsService = _FakePluginWarmupSettingsService(enabled: true);
    final service = PluginWarmupService(
      sessionRepository: sessionRepository,
      pluginRuntime: pluginRuntime,
      settingsService: settingsService,
    );

    final warmup = service.warmForSession(sessionId: "session-one");
    settingsService.enabled = false;
    pluginLookup.complete(_storedSession(id: "session-one"));
    await warmup;

    expect(pluginRuntime.startedPluginIds, isEmpty);
  });
}

typedef _SessionLookup = Future<StoredSession?> Function({required String sessionId});

class _FakeSessionRepository({this.lookup}) implements SessionRepository {
  final _SessionLookup? lookup;
  final List<String> lookups = [];

  @override
  Future<StoredSession?> getStoredSession({required String sessionId}) async {
    lookups.add(sessionId);
    return await lookup?.call(sessionId: sessionId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePluginRuntime() implements PluginRuntime {
  final List<String> startedPluginIds = [];

  @override
  Future<PluginRuntimeCommandResult> start({required String pluginId}) async {
    startedPluginIds.add(pluginId);
    return const PluginRuntimeCommandCurrent(snapshot: _activeSnapshot);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePluginWarmupSettingsService({required this.enabled}) implements PluginWarmupSettingsService {
  bool enabled;

  @override
  bool get isEnabled => enabled;

  @override
  Stream<bool> get states => Stream<bool>.value(enabled);

  @override
  Future<bool> update({required bool enabled}) async => this.enabled = enabled;
}

StoredSession _storedSession({required String id}) => StoredSession(
  id: id,
  backendSessionId: id,
  pluginId: "opencode",
  projectId: "project-one",
  parentSessionId: null,
  directory: "/project",
  worktreePath: null,
  branchName: null,
  isDedicated: false,
  archivedAt: null,
  baseBranch: null,
  baseCommit: null,
);

const _activeSnapshot = PluginRuntimeSnapshot(
  pluginId: "opencode",
  projectOwnership: PluginProjectOwnership.native,
  setup: PluginSetupReady(),
  accessGate: PluginRuntimeAccessGate.enabled,
  startAllowed: true,
  generation: 1,
  state: PluginRuntimeState.active,
  workState: PluginWorkState.idle,
  leaseCount: 0,
  transition: PluginRuntimeTransition.none,
);
