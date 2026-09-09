import "dart:async";

import "package:sesori_bridge/src/listeners/plugin_warmup_setting_listener.dart";
import "package:sesori_bridge/src/repositories/bridge_settings_repository.dart";
import "package:sesori_bridge/src/services/plugin_warmup_service.dart";
import "package:sesori_bridge/src/services/plugin_warmup_settings_service.dart";
import "package:sesori_bridge/src/services/session_view_tracker.dart";
import "package:test/test.dart";

import "../helpers/in_memory_bridge_settings_api.dart";

void main() {
  test("enabling the live setting immediately warms sessions already being viewed", () async {
    final fixture = await _createFixture(enabled: false);
    addTearDown(fixture.dispose);
    fixture.listener.start();
    fixture.tracker.setViewing(connID: 1, sessionId: "session-one");
    await Future<void>.delayed(Duration.zero);
    expect(fixture.warmupService.sessionIds, isEmpty);

    await fixture.settingsService.update(enabled: true);
    await _waitUntil(
      predicate: () => fixture.warmupService.sessionIds.contains("session-one"),
    );

    expect(fixture.warmupService.sessionIds, ["session-one"]);
  });

  test("the settings state stream admits the initial enabled state", () async {
    final fixture = await _createFixture(enabled: true);
    addTearDown(fixture.dispose);
    fixture.tracker.setViewing(connID: 1, sessionId: "session-one");

    fixture.listener.start();
    await _waitUntil(
      predicate: () => fixture.warmupService.sessionIds.contains("session-one"),
    );

    expect(fixture.warmupService.sessionIds, ["session-one"]);
  });
}

class _Fixture._({
  required final BridgeSettingsRepository settingsRepository,
  required final PluginWarmupSettingsService settingsService,
  required final SessionViewTracker tracker,
  required final _FakePluginWarmupService warmupService,
  required final PluginWarmupSettingListener listener,
});

Future<_Fixture> _createFixture({required bool enabled}) async {
  final settingsRepository = BridgeSettingsRepository(
    defaultEditorApi: null,
    api: InMemoryBridgeSettingsApi(
      config:
          '{"pullRequestRefreshIntervalSeconds":30,'
          '"warmUpPluginsOnSessionOpen":$enabled}',
    ),
  );
  await settingsRepository.loadSettings();
  final settingsService = PluginWarmupSettingsService(
    bridgeSettingsRepository: settingsRepository,
  );
  final tracker = SessionViewTracker();
  final warmupService = _FakePluginWarmupService();
  return _Fixture._(
    settingsRepository: settingsRepository,
    settingsService: settingsService,
    tracker: tracker,
    warmupService: warmupService,
    listener: PluginWarmupSettingListener(
      tracker: tracker,
      warmupService: warmupService,
      settingsService: settingsService,
    ),
  );
}

extension on _Fixture {
  Future<void> dispose() async {
    await listener.dispose();
    await tracker.dispose();
    await settingsRepository.dispose();
  }
}

class _FakePluginWarmupService() implements PluginWarmupService {
  final List<String> sessionIds = [];

  @override
  Future<void> warmForSession({required String sessionId}) async {
    sessionIds.add(sessionId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _waitUntil({required bool Function() predicate}) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail("Condition was not reached");
}
