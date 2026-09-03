import "dart:async";

import "package:sesori_bridge/src/listeners/viewed_session_plugin_warmup_listener.dart";
import "package:sesori_bridge/src/repositories/bridge_settings_repository.dart";
import "package:sesori_bridge/src/services/plugin_warmup_service.dart";
import "package:sesori_bridge/src/services/plugin_warmup_settings_service.dart";
import "package:sesori_bridge/src/services/session_view_tracker.dart";
import "package:test/test.dart";

import "../helpers/in_memory_bridge_settings_api.dart";

void main() {
  test("session view starts warm plugins only while the setting is enabled", () async {
    final settingsRepository = BridgeSettingsRepository(
      defaultEditorApi: null,
      api: InMemoryBridgeSettingsApi(
        config:
            '{"pullRequestRefreshIntervalSeconds":30,'
            '"warmUpPluginsOnSessionOpen":false}',
      ),
    );
    await settingsRepository.loadSettings();
    final tracker = SessionViewTracker();
    final warmupService = _FakePluginWarmupService();
    final settingsService = PluginWarmupSettingsService(
      bridgeSettingsRepository: settingsRepository,
    );
    final listener = ViewedSessionPluginWarmupListener(
      tracker: tracker,
      warmupService: warmupService,
      settingsService: settingsService,
    );
    addTearDown(() async {
      await listener.dispose();
      await tracker.dispose();
      await settingsRepository.dispose();
    });
    listener.start();

    tracker.setViewing(connID: 1, sessionId: "session-one");
    await Future<void>.delayed(Duration.zero);
    expect(warmupService.sessionIds, isEmpty);

    await settingsService.update(enabled: true);
    await Future<void>.delayed(Duration.zero);
    expect(settingsRepository.currentSettings.warmUpPluginsOnSessionOpen, isTrue);
    expect(warmupService.sessionIds, isEmpty);

    tracker.setViewing(connID: 2, sessionId: "session-two");
    await _waitUntil(predicate: () => warmupService.sessionIds.contains("session-two"));
    expect(warmupService.sessionIds, ["session-two"]);
  });
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
