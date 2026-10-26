import "dart:async";

import "package:sesori_bridge/src/repositories/bridge_settings.dart";
import "package:sesori_bridge/src/repositories/bridge_settings_repository.dart";
import "package:sesori_bridge/src/services/pull_request_refresh_settings_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/in_memory_bridge_settings_api.dart";

void main() {
  group("PullRequestRefreshSettingsService", () {
    late InMemoryBridgeSettingsApi api;
    late BridgeSettingsRepository repository;
    late PullRequestRefreshSettingsService service;

    setUp(() async {
      api = InMemoryBridgeSettingsApi(
        config: '{"pullRequestRefreshIntervalSeconds":30,"warmUpPluginsOnSessionOpen":true}',
      );
      repository = BridgeSettingsRepository(defaultEditorApi: null, api: api);
      await repository.loadSettings();
      service = PullRequestRefreshSettingsService(bridgeSettingsRepository: repository);
    });

    tearDown(() => repository.dispose());

    test("returns the loaded committed interval", () async {
      expect(await service.readCommittedSettings(), const PullRequestRefreshSettingsResponse(intervalSeconds: 30));
    });

    test("an ordered read waits for an active mutation to commit", () async {
      final writeStarted = Completer<void>();
      final releaseWrite = Completer<void>();
      api
        ..writeStarted = writeStarted
        ..releaseWrite = releaseWrite;
      final update = service.update(intervalSeconds: 45);
      await writeStarted.future;
      var readCompleted = false;
      final read = service.readCommittedSettings().then((response) {
        readCompleted = true;
        return response;
      });

      await Future<void>.delayed(Duration.zero);
      expect(readCompleted, isFalse);

      releaseWrite.complete();
      expect(await read, const PullRequestRefreshSettingsResponse(intervalSeconds: 45));
      expect(await update, const PullRequestRefreshSettingsResponse(intervalSeconds: 45));
    });

    test("persists accepted boundary values", () async {
      for (final intervalSeconds in [
        minimumPullRequestRefreshIntervalSeconds,
        maximumPullRequestRefreshIntervalSeconds,
      ]) {
        final response = await service.update(
          intervalSeconds: intervalSeconds,
        );

        expect(response.intervalSeconds, intervalSeconds);
        expect(repository.currentSettings.pullRequestRefreshIntervalSeconds, intervalSeconds);
        expect(jsonDecodeMap(api.config!)["pullRequestRefreshIntervalSeconds"], intervalSeconds);
      }
    });

    test("rejects out-of-range values without persisting", () async {
      for (final intervalSeconds in [
        minimumPullRequestRefreshIntervalSeconds - 1,
        maximumPullRequestRefreshIntervalSeconds + 1,
      ]) {
        final matcher = isA<PullRequestRefreshIntervalOutOfRangeException>()
            .having(
              (error) => error.intervalSeconds,
              "intervalSeconds",
              intervalSeconds,
            )
            .having(
              (error) => error.toString(),
              "diagnostic description",
              allOf(contains("$intervalSeconds"), contains("15"), contains("3600")),
            );
        await expectLater(
          service.update(
            intervalSeconds: intervalSeconds,
          ),
          throwsA(matcher),
        );
      }

      expect(api.writeCount, 0);
      expect(repository.currentSettings.pullRequestRefreshIntervalSeconds, 30);
    });

    test("an unchanged value does not rewrite", () async {
      final response = await service.update(
        intervalSeconds: 30,
      );

      expect(response.intervalSeconds, 30);
      expect(api.writeCount, 0);
    });
  });
}
