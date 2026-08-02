import "dart:convert";

import "package:sesori_bridge/src/api/bridge_settings_api.dart";
import "package:sesori_bridge/src/repositories/bridge_settings.dart";
import "package:sesori_bridge/src/repositories/bridge_settings_repository.dart";
import "package:sesori_bridge/src/services/pull_request_refresh_settings_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("PullRequestRefreshSettingsService", () {
    late _MemoryBridgeSettingsApi api;
    late BridgeSettingsRepository repository;
    late PullRequestRefreshSettingsService service;

    setUp(() async {
      api = _MemoryBridgeSettingsApi(
        config: '{"pullRequestRefreshIntervalSeconds":30}',
      );
      repository = BridgeSettingsRepository(api: api);
      await repository.loadSettings();
      service = PullRequestRefreshSettingsService(bridgeSettingsRepository: repository);
    });

    tearDown(() => repository.dispose());

    test("returns the loaded committed interval", () {
      expect(service.currentSettings, const PullRequestRefreshSettingsResponse(intervalSeconds: 30));
    });

    test("persists and publishes accepted boundary values", () async {
      final changes = <PullRequestRefreshSettingsResponse>[];
      final subscription = service.changes.listen(changes.add);

      for (final intervalSeconds in [
        minimumPullRequestRefreshIntervalSeconds,
        maximumPullRequestRefreshIntervalSeconds,
      ]) {
        final response = await service.update(
          request: PullRequestRefreshSettingsRequest(intervalSeconds: intervalSeconds),
        );

        expect(response.intervalSeconds, intervalSeconds);
        expect(repository.currentSettings.pullRequestRefreshIntervalSeconds, intervalSeconds);
        expect((jsonDecode(api.config!) as Map)["pullRequestRefreshIntervalSeconds"], intervalSeconds);
      }
      expect(changes.map((change) => change.intervalSeconds), [15, 3600]);
      await subscription.cancel();
    });

    test("rejects out-of-range values without persisting or publishing", () async {
      final changes = <PullRequestRefreshSettingsResponse>[];
      final subscription = service.changes.listen(changes.add);

      for (final intervalSeconds in [
        minimumPullRequestRefreshIntervalSeconds - 1,
        maximumPullRequestRefreshIntervalSeconds + 1,
      ]) {
        await expectLater(
          service.update(
            request: PullRequestRefreshSettingsRequest(intervalSeconds: intervalSeconds),
          ),
          throwsA(
            isA<PullRequestRefreshIntervalOutOfRangeException>().having(
              (error) => error.intervalSeconds,
              "intervalSeconds",
              intervalSeconds,
            ),
          ),
        );
      }

      expect(api.writeCount, 0);
      expect(changes, isEmpty);
      expect(service.currentSettings.intervalSeconds, 30);
      await subscription.cancel();
    });

    test("an unchanged value does not rewrite or publish", () async {
      final changes = <PullRequestRefreshSettingsResponse>[];
      final subscription = service.changes.listen(changes.add);

      final response = await service.update(
        request: const PullRequestRefreshSettingsRequest(intervalSeconds: 30),
      );

      expect(response.intervalSeconds, 30);
      expect(api.writeCount, 0);
      expect(changes, isEmpty);
      await subscription.cancel();
    });

    test("unrelated committed settings do not publish a cadence change", () async {
      final changes = <PullRequestRefreshSettingsResponse>[];
      final subscription = service.changes.listen(changes.add);

      await repository.mutateSettings(
        mutation: ({required current}) => current.copyWith(
          plugins: current.plugins.withPluginDisabled(pluginId: "cursor", disabled: true),
        ),
      );

      expect(changes, isEmpty);
      expect(service.currentSettings.intervalSeconds, 30);
      await subscription.cancel();
    });
  });
}

class _MemoryBridgeSettingsApi implements BridgeSettingsApi {
  _MemoryBridgeSettingsApi({required this.config});

  String? config;
  int writeCount = 0;

  @override
  String get configFilePath => "/tmp/config.json";

  @override
  Future<String?> readConfig() async => config;

  @override
  Future<void> writeConfig(String jsonContent) async {
    config = jsonContent;
    writeCount++;
  }
}
