import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/models/connection_status.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/cubits/bridge_settings/bridge_settings_cubit.dart";
import "package:sesori_dart_core/src/cubits/bridge_settings/bridge_settings_state.dart";
import "package:sesori_dart_core/src/repositories/models/bridge_settings_result.dart";
import "package:sesori_dart_core/src/services/bridge_settings_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockBridgeSettingsService() extends Mock implements BridgeSettingsService;

void main() {
  late _MockBridgeSettingsService service;
  late _FakeConnectionService connection;

  setUp(() {
    service = _MockBridgeSettingsService();
    connection = _FakeConnectionService(initialStatus: _connected);
    addTearDown(connection.dispose);
  });

  test("loads one aggregate snapshot", () async {
    _stubLoad(service, yoloEnabled: true);
    final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);

    await _waitForState<BridgeSettingsReady>(cubit);

    final state = cubit.state as BridgeSettingsReady;
    expect(state.yoloEnabled, isTrue);
    expect(state.yoloMutation, isA<YoloMutationIdle>());
    expect((state.pluginWarmupMutation as PluginWarmupMutationIdle).enabled, isTrue);
    verify(service.load).called(1);
  });

  test("treats session-open warm-up as unsupported when an older aggregate omits it", () async {
    when(service.load).thenAnswer(
      (_) async => const BridgeSettingsLoadSupported(
        response: BridgeSettingsResponse(
          pullRequestRefresh: PullRequestRefreshSettingsResponse(intervalSeconds: 30),
          yolo: YoloSettingsResponse(enabled: false),
          warmUpPluginsOnSessionOpen: null,
          agentToolsEnabled: null,
          releaseTrack: null,
          preventSleep: null,
        ),
      ),
    );
    final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);

    await _waitForState<BridgeSettingsReady>(cubit);

    expect(
      (cubit.state as BridgeSettingsReady).pluginWarmupMutation,
      isA<PluginWarmupMutationUnsupported>(),
    );
  });

  group("agent tools", () {
    test("a bridge without the master switch or tool groups has no agent tools section", () async {
      when(service.load).thenAnswer(
        (_) async => _loadResult(yoloEnabled: false, agentToolsEnabled: null, toolGroups: const []),
      );
      final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
      addTearDown(cubit.close);

      await _waitForState<BridgeSettingsReady>(cubit);

      expect((cubit.state as BridgeSettingsReady).agentTools, isNull);
    });

    test("loads the master switch and each group", () async {
      when(service.load).thenAnswer((_) async => _loadResult(yoloEnabled: false, agentToolsEnabled: false));
      final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
      addTearDown(cubit.close);

      await _waitForState<BridgeSettingsReady>(cubit);

      final agentTools = _agentToolsOf(cubit);
      expect(agentTools.enabled, isFalse);
      expect(agentTools.groups, [_prMonitor]);
      expect(agentTools.mutation, isA<AgentToolsMutationIdle>());
    });

    test("turning the master off keeps each group's own switch", () async {
      _stubLoad(service, yoloEnabled: false);
      when(() => service.updateAgentTools(enabled: false)).thenAnswer(
        (_) async => const AgentToolsSettingsMutationCommitted(enabled: false),
      );
      final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
      addTearDown(cubit.close);
      await _waitForState<BridgeSettingsReady>(cubit);

      final saving = cubit.updateAgentTools(enabled: false, expectedState: cubit.state as BridgeSettingsReady);
      expect(_agentToolsOf(cubit).mutation, isA<AgentToolsMutationInProgress>());
      await saving;

      final agentTools = _agentToolsOf(cubit);
      expect(agentTools.enabled, isFalse);
      expect(agentTools.groups, [_prMonitor]);
      expect(agentTools.mutation, isA<AgentToolsMutationIdle>());
    });

    test("a group change replaces only that group", () async {
      _stubLoad(service, yoloEnabled: false);
      when(() => service.updateToolGroup(id: "pr_monitor", enabled: false)).thenAnswer(
        (_) async => const AgentToolsSettingsMutationCommitted(enabled: false),
      );
      final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
      addTearDown(cubit.close);
      await _waitForState<BridgeSettingsReady>(cubit);

      await cubit.updateToolGroup(
        id: "pr_monitor",
        enabled: false,
        expectedState: cubit.state as BridgeSettingsReady,
      );

      final agentTools = _agentToolsOf(cubit);
      expect(agentTools.enabled, isTrue);
      expect(agentTools.groups, [_prMonitor.copyWith(enabled: false)]);
    });

    test("a failed save names the switch and keeps its state", () async {
      _stubLoad(service, yoloEnabled: false);
      when(() => service.updateToolGroup(id: "pr_monitor", enabled: false)).thenAnswer(
        (_) async => AgentToolsSettingsMutationFailure(error: ApiError.generic()),
      );
      final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
      addTearDown(cubit.close);
      await _waitForState<BridgeSettingsReady>(cubit);

      await cubit.updateToolGroup(
        id: "pr_monitor",
        enabled: false,
        expectedState: cubit.state as BridgeSettingsReady,
      );

      final agentTools = _agentToolsOf(cubit);
      expect(agentTools.groups, [_prMonitor]);
      expect(
        agentTools.mutation,
        isA<AgentToolsMutationFailed>().having(
          (failed) => failed.target,
          "target",
          isA<AgentToolGroupSwitch>().having((target) => target.id, "id", "pr_monitor"),
        ),
      );
    });

    test("an uncertain save reloads the bridge's settings", () async {
      var loads = 0;
      when(service.load).thenAnswer(
        (_) async => _loadResult(yoloEnabled: false, agentToolsEnabled: loads++ == 0),
      );
      when(() => service.updateAgentTools(enabled: false)).thenAnswer(
        (_) async => const AgentToolsSettingsMutationUncertain(),
      );
      final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
      addTearDown(cubit.close);
      await _waitForState<BridgeSettingsReady>(cubit);

      await cubit.updateAgentTools(enabled: false, expectedState: cubit.state as BridgeSettingsReady);

      final agentTools = _agentToolsOf(cubit);
      expect(agentTools.enabled, isFalse);
      expect(agentTools.mutation, isA<AgentToolsMutationIdle>());
    });
  });

  group("prevent sleep", () {
    test("a bridge that does not report the setting has no row", () async {
      when(service.load).thenAnswer((_) async => _loadResult(yoloEnabled: false, preventSleep: null));
      final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
      addTearDown(cubit.close);

      await _waitForState<BridgeSettingsReady>(cubit);

      expect((cubit.state as BridgeSettingsReady).preventSleep, isNull);
    });

    test("remembers the row through a failed load and a dropped connection", () async {
      when(service.load).thenAnswer((_) async => _loadResult(yoloEnabled: false));
      final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
      addTearDown(cubit.close);
      await _waitForState<BridgeSettingsReady>(cubit);

      when(service.load).thenAnswer((_) async => BridgeSettingsLoadFailure(error: ApiError.generic()));
      await cubit.refresh();
      expect((cubit.state as BridgeSettingsFailure).reported.preventSleep, isTrue);

      connection.emitStatus(const ConnectionStatus.connectionLost(config: _config));
      await _waitForState<BridgeSettingsDisconnected>(cubit);
      expect((cubit.state as BridgeSettingsDisconnected).reported.preventSleep, isTrue);
    });

    test("commits a change and shows it in progress meanwhile", () async {
      when(service.load).thenAnswer((_) async => _loadResult(yoloEnabled: false));
      when(() => service.updatePreventSleep(enabled: false)).thenAnswer(
        (_) async => const PreventSleepSettingsMutationCommitted(enabled: false),
      );
      final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
      addTearDown(cubit.close);
      await _waitForState<BridgeSettingsReady>(cubit);

      final saving = cubit.updatePreventSleep(enabled: false, expectedState: cubit.state as BridgeSettingsReady);
      expect(_preventSleepOf(cubit).mutation, isA<PreventSleepMutationInProgress>());
      expect(_preventSleepOf(cubit).enabled, isTrue);
      await saving;

      expect(_preventSleepOf(cubit).enabled, isFalse);
      expect(_preventSleepOf(cubit).mutation, isA<PreventSleepMutationIdle>());
    });

    test("keeps the old value on a failed save", () async {
      final error = ApiError.generic();
      when(service.load).thenAnswer((_) async => _loadResult(yoloEnabled: false));
      when(() => service.updatePreventSleep(enabled: false)).thenAnswer(
        (_) async => PreventSleepSettingsMutationFailure(error: error),
      );
      final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
      addTearDown(cubit.close);
      await _waitForState<BridgeSettingsReady>(cubit);

      await cubit.updatePreventSleep(enabled: false, expectedState: cubit.state as BridgeSettingsReady);

      expect(_preventSleepOf(cubit).enabled, isTrue);
      expect(
        _preventSleepOf(cubit).mutation,
        isA<PreventSleepMutationFailed>().having((failed) => failed.error, "error", same(error)),
      );
    });

    test("an uncertain save reloads, and stays uncertain when the reload fails", () async {
      final refreshError = ApiError.generic();
      var loads = 0;
      when(service.load).thenAnswer(
        (_) async => loads++ == 0 ? _loadResult(yoloEnabled: false) : BridgeSettingsLoadFailure(error: refreshError),
      );
      when(() => service.updatePreventSleep(enabled: false)).thenAnswer(
        (_) async => const PreventSleepSettingsMutationUncertain(),
      );
      final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
      addTearDown(cubit.close);
      await _waitForState<BridgeSettingsReady>(cubit);

      await cubit.updatePreventSleep(enabled: false, expectedState: cubit.state as BridgeSettingsReady);

      expect(_preventSleepOf(cubit).enabled, isTrue);
      expect(
        _preventSleepOf(cubit).mutation,
        isA<PreventSleepMutationUncertain>().having((uncertain) => uncertain.refreshError, "error", same(refreshError)),
      );
    });
  });

  group("release track", () {
    test("a bridge that does not report its track, or reports one this app does not know, has no row", () async {
      for (final track in [null, BridgeReleaseTrack.unknown]) {
        when(service.load).thenAnswer((_) async => _loadResult(yoloEnabled: false, releaseTrack: track));
        final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
        await _waitForState<BridgeSettingsReady>(cubit);

        expect((cubit.state as BridgeSettingsReady).releaseTrack, isNull);
        await cubit.close();
      }
    });

    test("loads the track", () async {
      when(service.load).thenAnswer(
        (_) async => _loadResult(yoloEnabled: false, releaseTrack: BridgeReleaseTrack.internal),
      );
      final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
      addTearDown(cubit.close);

      await _waitForState<BridgeSettingsReady>(cubit);

      expect(_releaseTrackOf(cubit).internalBuilds, isTrue);
      expect(_releaseTrackOf(cubit).mutation, isA<ReleaseTrackMutationIdle>());
    });

    test("remembers the track through a reload, a failed load and a dropped connection", () async {
      when(service.load).thenAnswer(
        (_) async => _loadResult(yoloEnabled: false, releaseTrack: BridgeReleaseTrack.stable),
      );
      final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
      addTearDown(cubit.close);
      expect((cubit.state as BridgeSettingsLoading).reported.releaseTrack, isFalse);
      await _waitForState<BridgeSettingsReady>(cubit);

      when(service.load).thenAnswer((_) async => BridgeSettingsLoadFailure(error: ApiError.generic()));
      final reloading = cubit.refresh();
      expect((cubit.state as BridgeSettingsLoading).reported.releaseTrack, isTrue);
      await reloading;
      expect((cubit.state as BridgeSettingsFailure).reported.releaseTrack, isTrue);

      connection.emitStatus(const ConnectionStatus.connectionLost(config: _config));
      await _waitForState<BridgeSettingsDisconnected>(cubit);
      expect((cubit.state as BridgeSettingsDisconnected).reported.releaseTrack, isTrue);
    });

    test("commits a change without reloading the bridge", () async {
      _stubLoad(service, yoloEnabled: false);
      when(() => service.updateReleaseTrack(internalBuilds: true)).thenAnswer(
        (_) async => const ReleaseTrackSettingsMutationCommitted(internalBuilds: true),
      );
      final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
      addTearDown(cubit.close);
      await _waitForState<BridgeSettingsReady>(cubit);

      final saving = cubit.updateReleaseTrack(internalBuilds: true, expectedState: cubit.state as BridgeSettingsReady);
      expect(_releaseTrackOf(cubit).mutation, isA<ReleaseTrackMutationInProgress>());
      expect(_releaseTrackOf(cubit).internalBuilds, isFalse);
      await saving;

      expect(_releaseTrackOf(cubit).internalBuilds, isTrue);
      expect(_releaseTrackOf(cubit).mutation, isA<ReleaseTrackMutationIdle>());
      verify(service.load).called(1);
    });

    test("a failed save keeps the track and stays retryable", () async {
      _stubLoad(service, yoloEnabled: false);
      final error = ApiError.generic();
      when(() => service.updateReleaseTrack(internalBuilds: true)).thenAnswer(
        (_) async => ReleaseTrackSettingsMutationFailure(error: error),
      );
      final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
      addTearDown(cubit.close);
      await _waitForState<BridgeSettingsReady>(cubit);

      await cubit.updateReleaseTrack(internalBuilds: true, expectedState: cubit.state as BridgeSettingsReady);

      expect(_releaseTrackOf(cubit).internalBuilds, isFalse);
      expect(
        _releaseTrackOf(cubit).mutation,
        isA<ReleaseTrackMutationFailed>().having((failed) => failed.error, "error", same(error)),
      );
      await cubit.updateReleaseTrack(internalBuilds: true, expectedState: cubit.state as BridgeSettingsReady);
      verify(() => service.updateReleaseTrack(internalBuilds: true)).called(2);
    });

    test("an uncertain save reloads the bridge's settings", () async {
      var loads = 0;
      when(service.load).thenAnswer(
        (_) async => _loadResult(
          yoloEnabled: false,
          releaseTrack: loads++ == 0 ? BridgeReleaseTrack.stable : BridgeReleaseTrack.internal,
        ),
      );
      when(() => service.updateReleaseTrack(internalBuilds: true)).thenAnswer(
        (_) async => const ReleaseTrackSettingsMutationUncertain(),
      );
      final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
      addTearDown(cubit.close);
      await _waitForState<BridgeSettingsReady>(cubit);

      await cubit.updateReleaseTrack(internalBuilds: true, expectedState: cubit.state as BridgeSettingsReady);

      expect(_releaseTrackOf(cubit).internalBuilds, isTrue);
      expect(_releaseTrackOf(cubit).mutation, isA<ReleaseTrackMutationIdle>());
    });

    test("an uncertain save whose reload fails stays uncertain", () async {
      var loads = 0;
      final refreshError = ApiError.generic();
      when(service.load).thenAnswer(
        (_) async => loads++ == 0 ? _loadResult(yoloEnabled: false) : BridgeSettingsLoadFailure(error: refreshError),
      );
      when(() => service.updateReleaseTrack(internalBuilds: true)).thenAnswer(
        (_) async => const ReleaseTrackSettingsMutationUncertain(),
      );
      final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
      addTearDown(cubit.close);
      await _waitForState<BridgeSettingsReady>(cubit);

      await cubit.updateReleaseTrack(internalBuilds: true, expectedState: cubit.state as BridgeSettingsReady);

      expect(_releaseTrackOf(cubit).internalBuilds, isFalse);
      expect(
        _releaseTrackOf(cubit).mutation,
        isA<ReleaseTrackMutationUncertain>().having((uncertain) => uncertain.refreshError, "error", same(refreshError)),
      );
    });
  });

  test("a bridge without the settings route is unsupported", () async {
    when(service.load).thenAnswer((_) async => const BridgeSettingsLoadUnsupported());
    final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);

    await _waitForState<BridgeSettingsUnsupported>(cubit);

    verify(service.load).called(1);
  });

  test("keeps setting mutation presentation independent", () async {
    _stubLoad(service, yoloEnabled: false);
    when(() => service.updateYolo(enabled: true)).thenAnswer(
      (_) async => YoloSettingsMutationFailure(error: ApiError.generic()),
    );
    when(() => service.updatePluginWarmup(enabled: false)).thenAnswer(
      (_) async => const PluginWarmupSettingsMutationCommitted(enabled: false),
    );
    final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<BridgeSettingsReady>(cubit);

    await cubit.updateYolo(enabled: true, expectedState: cubit.state as BridgeSettingsReady);
    final afterYolo = cubit.state as BridgeSettingsReady;
    expect(afterYolo.yoloMutation, isA<YoloMutationFailed>());
    expect((afterYolo.pluginWarmupMutation as PluginWarmupMutationIdle).enabled, isTrue);

    await cubit.updatePluginWarmup(enabled: false, expectedState: afterYolo);
    final afterWarmup = cubit.state as BridgeSettingsReady;
    expect((afterWarmup.pluginWarmupMutation as PluginWarmupMutationIdle).enabled, isFalse);
    expect(afterWarmup.yoloMutation, isA<YoloMutationFailed>());
  });

  test("commits session-open warm-up without reloading the bridge", () async {
    _stubLoad(service, yoloEnabled: false);
    when(() => service.updatePluginWarmup(enabled: false)).thenAnswer(
      (_) async => const PluginWarmupSettingsMutationCommitted(enabled: false),
    );
    final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<BridgeSettingsReady>(cubit);

    await cubit.updatePluginWarmup(
      enabled: false,
      expectedState: cubit.state as BridgeSettingsReady,
    );

    final mutation = (cubit.state as BridgeSettingsReady).pluginWarmupMutation;
    expect((mutation as PluginWarmupMutationIdle).enabled, isFalse);
    verify(() => service.updatePluginWarmup(enabled: false)).called(1);
    verify(service.load).called(1);
  });

  test("unexpected load failures remain retryable", () async {
    var loadCalls = 0;
    when(service.load).thenAnswer((_) {
      loadCalls++;
      if (loadCalls == 1) throw StateError("unexpected load failure");
      return Future.value(_loadResult(yoloEnabled: false));
    });
    final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<BridgeSettingsFailure>(cubit);

    await cubit.refresh();

    expect(cubit.state, isA<BridgeSettingsReady>());
    expect(loadCalls, 2);
  });

  test("failed uncertain reconciliation affects only the mutated row", () async {
    var loadCalls = 0;
    when(service.load).thenAnswer((_) async {
      loadCalls++;
      return loadCalls == 1 ? _loadResult(yoloEnabled: false) : BridgeSettingsLoadFailure(error: ApiError.generic());
    });
    when(() => service.updateYolo(enabled: true)).thenAnswer((_) async => const YoloSettingsMutationUncertain());
    final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<BridgeSettingsReady>(cubit);

    await cubit.updateYolo(enabled: true, expectedState: cubit.state as BridgeSettingsReady);

    final state = cubit.state as BridgeSettingsReady;
    expect(state.yoloMutation, isA<YoloMutationUncertain>());
    expect((state.pluginWarmupMutation as PluginWarmupMutationIdle).enabled, isTrue);
  });

  test("closing during an aggregate load suppresses its late result", () async {
    final load = Completer<BridgeSettingsLoadResult>();
    when(service.load).thenAnswer((_) => load.future);
    final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
    await _waitUntil(() => cubit.state is BridgeSettingsLoading);

    final close = cubit.close();
    load.complete(_loadResult(yoloEnabled: true));
    await close;

    expect(cubit.isClosed, isTrue);
  });

  test("reconciles an uncertain mutation with one aggregate reload", () async {
    var loadCalls = 0;
    when(service.load).thenAnswer((_) async {
      loadCalls++;
      return _loadResult(yoloEnabled: loadCalls > 1);
    });
    when(() => service.updateYolo(enabled: true)).thenAnswer((_) async => const YoloSettingsMutationUncertain());
    final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<BridgeSettingsReady>(cubit);

    await cubit.updateYolo(enabled: true, expectedState: cubit.state as BridgeSettingsReady);

    expect((cubit.state as BridgeSettingsReady).yoloEnabled, isTrue);
    expect(loadCalls, 2);
  });

  test("coalesces refresh requested during a mutation", () async {
    var loadCalls = 0;
    when(service.load).thenAnswer((_) async {
      loadCalls++;
      return _loadResult(yoloEnabled: false);
    });
    final mutation = Completer<YoloSettingsMutationResult>();
    when(() => service.updateYolo(enabled: true)).thenAnswer((_) => mutation.future);
    final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitForState<BridgeSettingsReady>(cubit);

    final update = cubit.updateYolo(enabled: true, expectedState: cubit.state as BridgeSettingsReady);
    await _waitUntil(
      () => switch (cubit.state) {
        BridgeSettingsReady(yoloMutation: YoloMutationInProgress()) => true,
        _ => false,
      },
    );
    await cubit.refresh();
    await cubit.refresh();
    mutation.complete(
      const YoloSettingsMutationCommitted(response: YoloSettingsResponse(enabled: true)),
    );
    await update;
    await _waitUntil(() => loadCalls >= 2);

    verify(service.load).called(2);
  });

  test("fences obsolete loads across reconnect and ignores stale toggles", () async {
    final firstLoad = Completer<BridgeSettingsLoadResult>();
    var loadCalls = 0;
    when(service.load).thenAnswer((_) {
      loadCalls++;
      return loadCalls == 1 ? firstLoad.future : Future.value(_loadResult(yoloEnabled: false));
    });
    final cubit = BridgeSettingsCubit(service: service, connectionService: connection);
    addTearDown(cubit.close);
    await _waitUntil(() => loadCalls == 1);
    connection.emitStatus(const ConnectionStatus.connectionLost(config: _config));
    connection.emitStatus(_connected);
    firstLoad.complete(_loadResult(yoloEnabled: true));
    await _waitUntil(
      () => switch (cubit.state) {
        BridgeSettingsReady(yoloEnabled: false) => true,
        _ => false,
      },
    );
    final current = cubit.state;

    await cubit.updateYolo(
      enabled: false,
      expectedState: const BridgeSettingsReady(
        yoloEnabled: true,
        yoloMutation: YoloMutationIdle(),
        pluginWarmupMutation: PluginWarmupMutationIdle(enabled: true),
        agentTools: null,
        releaseTrack: null,
        preventSleep: null,
      ),
    );

    expect(cubit.state, same(current));
    verifyNever(() => service.updateYolo(enabled: any(named: "enabled")));
  });
}

const _config = ServerConnectionConfig(relayHost: "relay.example.com", authToken: null, bridgeId: null);
const _health = HealthResponse(healthy: true, version: "test", filesystemAccessDegraded: false);
const _connected = ConnectionStatus.connected(config: _config, health: _health);

const _prMonitor = BridgeToolGroupSetting(
  id: "pr_monitor",
  title: "PR monitor",
  summary: "Agents can watch pull requests.",
  enabled: true,
);

BridgeSettingsLoadSupported _loadResult({
  required bool yoloEnabled,
  bool? agentToolsEnabled = true,
  List<BridgeToolGroupSetting> toolGroups = const [_prMonitor],
  BridgeReleaseTrack? releaseTrack = BridgeReleaseTrack.stable,
  bool? preventSleep = true,
}) {
  return BridgeSettingsLoadSupported(
    response: BridgeSettingsResponse(
      pullRequestRefresh: const PullRequestRefreshSettingsResponse(intervalSeconds: 30),
      yolo: YoloSettingsResponse(enabled: yoloEnabled),
      warmUpPluginsOnSessionOpen: true,
      agentToolsEnabled: agentToolsEnabled,
      releaseTrack: releaseTrack,
      preventSleep: preventSleep,
      toolGroups: toolGroups,
    ),
  );
}

PreventSleepSettings _preventSleepOf(BridgeSettingsCubit cubit) => switch (cubit.state) {
  BridgeSettingsReady(:final PreventSleepSettings preventSleep) => preventSleep,
  final other => fail("no prevent-sleep setting in $other"),
};

ReleaseTrackSettings _releaseTrackOf(BridgeSettingsCubit cubit) => switch (cubit.state) {
  BridgeSettingsReady(:final ReleaseTrackSettings releaseTrack) => releaseTrack,
  final other => fail("no release track in $other"),
};

AgentToolsSettings _agentToolsOf(BridgeSettingsCubit cubit) => switch (cubit.state) {
  BridgeSettingsReady(:final AgentToolsSettings agentTools) => agentTools,
  final other => fail("no agent tools in $other"),
};

void _stubLoad(_MockBridgeSettingsService service, {required bool yoloEnabled}) {
  when(service.load).thenAnswer((_) async => _loadResult(yoloEnabled: yoloEnabled));
}

Future<void> _waitForState<T extends BridgeSettingsState>(BridgeSettingsCubit cubit) async {
  if (cubit.state is T) return;
  await cubit.stream.firstWhere((state) => state is T);
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail("Condition was not reached");
}

final class _FakeConnectionService({required ConnectionStatus initialStatus}) implements ConnectionService {
  final BehaviorSubject<ConnectionStatus> _statuses = BehaviorSubject.seeded(initialStatus);

  @override
  ConnectionStatus get currentStatus => _statuses.value;

  @override
  ValueStream<ConnectionStatus> get status => _statuses.stream;

  void emitStatus(ConnectionStatus status) => _statuses.add(status);

  @override
  Future<void> dispose() => _statuses.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
