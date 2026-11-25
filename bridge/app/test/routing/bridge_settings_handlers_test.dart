import "dart:convert";

import "package:sesori_bridge/src/repositories/bridge_settings_repository.dart";
import "package:sesori_bridge/src/repositories/models/sesori_tool_group_ids.dart";
import "package:sesori_bridge/src/routing/get_bridge_settings_handler.dart";
import "package:sesori_bridge/src/routing/patch_bridge_settings_handler.dart";
import "package:sesori_bridge/src/services/permission_auto_approval_service.dart";
import "package:sesori_bridge/src/services/plugin_warmup_settings_service.dart";
import "package:sesori_bridge/src/services/pull_request_refresh_settings_service.dart";
import "package:sesori_bridge/src/services/release_track_settings_service.dart";
import "package:sesori_bridge/src/services/session_mutation_dispatcher.dart";
import "package:sesori_bridge/src/services/sleep_prevention_service.dart";
import "package:sesori_bridge/src/services/tool_group_settings_service.dart";
import "package:sesori_bridge/src/services/yolo_settings_service.dart";
import "package:sesori_bridge/src/updater/foundation/release_track.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:sesori_tool_interface/sesori_tool_interface.dart";
import "package:test/test.dart";

import "../bridge/routing/routing_test_helpers.dart";
import "../helpers/in_memory_bridge_settings_api.dart";
import "../helpers/sleep_prevention_test_support.dart";

void main() {
  group("bridge settings handlers", () {
    late InMemoryBridgeSettingsApi api;
    late BridgeSettingsRepository repository;
    late YoloSettingsService service;
    late ToolGroupSettingsService toolGroups;
    late ReleaseTrackSettingsService releaseTrack;
    late RecordingWakeLockRepository wakeLock;
    late SleepPreventionService sleepPrevention;
    late PatchBridgeSettingsHandler patchHandler;

    setUp(() async {
      api = InMemoryBridgeSettingsApi(config: '{"yolo":false,"pullRequestRefreshIntervalSeconds":30}');
      repository = BridgeSettingsRepository(defaultEditorApi: null, api: api);
      await repository.loadSettings();
      service = YoloSettingsService(
        bridgeSettingsRepository: repository,
        permissionAutoApprovalService: _FakePermissionAutoApprovalService(),
        sessionMutationDispatcher: _FakeSessionMutationDispatcher(),
      );
      toolGroups = ToolGroupSettingsService(settings: repository, groups: [_FakeToolGroup()]);
      releaseTrack = ReleaseTrackSettingsService(settings: repository, updatesItself: true);
      wakeLock = RecordingWakeLockRepository();
      sleepPrevention = createTestSleepPreventionService(
        bridgeSettingsRepository: repository,
        wakeLockRepository: wakeLock,
      );
      patchHandler = PatchBridgeSettingsHandler(
        pullRequestRefreshSettingsService: PullRequestRefreshSettingsService(
          bridgeSettingsRepository: repository,
        ),
        yoloSettingsService: service,
        pluginWarmupSettingsService: PluginWarmupSettingsService(
          bridgeSettingsRepository: repository,
        ),
        toolGroupSettingsService: toolGroups,
        releaseTrackSettingsService: releaseTrack,
        sleepPreventionService: sleepPrevention,
      );
    });

    tearDown(() => repository.dispose());

    test("GET still serves the inert PR interval with the other settings from one committed snapshot", () async {
      final response =
          await GetBridgeSettingsHandler(
            settingsRepository: repository,
            toolGroupSettingsService: toolGroups,
            releaseTrackSettingsService: releaseTrack,
            sleepPreventionService: sleepPrevention,
          ).routeForTest(
            makeRequest("GET", "/settings"),
          );

      expect(response.status, 200);
      expect(
        BridgeSettingsResponse.fromJson(jsonDecodeMap(response.body ?? fail("missing body"))),
        const BridgeSettingsResponse(
          pullRequestRefresh: PullRequestRefreshSettingsResponse(intervalSeconds: 30),
          yolo: YoloSettingsResponse(enabled: false, supportsSessionOverride: true),
          warmUpPluginsOnSessionOpen: true,
          agentToolsEnabled: true,
          toolGroups: [
            BridgeToolGroupSetting(id: "tasks", title: "Fake", summary: "Agents can fake.", enabled: true),
          ],
          releaseTrack: BridgeReleaseTrack.stable,
          // The default choice is on, and this test never took the wake lock.
          preventSleep: SleepPreventionStatus.failed,
        ),
      );
    });

    test("PATCH persists and returns the committed setting", () async {
      final response = await patchHandler.routeForTest(
        makeRequest("PATCH", "/settings", body: jsonEncode(const BridgeSettingUpdate.yolo(enabled: true).toJson())),
      );

      expect(response.status, 200);
      expect(
        BridgeSettingUpdate.fromJson(jsonDecodeMap(response.body ?? fail("missing body"))),
        const BridgeSettingUpdate.yolo(enabled: true),
      );
      expect(jsonDecodeMap(api.config ?? fail("missing stored settings"))["yolo"], isTrue);
    });

    test("PATCH applies session-open plugin warm-up without a bridge restart", () async {
      final changes = <bool>[];
      final subscription = repository.settingsChanges.listen(
        (change) => changes.add(change.current.warmUpPluginsOnSessionOpen),
      );

      final response = await patchHandler.routeForTest(
        makeRequest(
          "PATCH",
          "/settings",
          body: jsonEncode(
            const BridgeSettingUpdate.warmUpPluginsOnSessionOpen(enabled: false).toJson(),
          ),
        ),
      );

      expect(response.status, 200);
      expect(
        BridgeSettingUpdate.fromJson(jsonDecodeMap(response.body ?? fail("missing body"))),
        const BridgeSettingUpdate.warmUpPluginsOnSessionOpen(enabled: false),
      );
      expect(repository.currentSettings.warmUpPluginsOnSessionOpen, isFalse);
      expect(jsonDecodeMap(api.config ?? fail("missing stored settings"))["warmUpPluginsOnSessionOpen"], isFalse);
      expect(changes, [false]);
      await subscription.cancel();
    });

    test("PATCH turns a tool group off and GET then lists it off", () async {
      final response = await patchHandler.routeForTest(
        makeRequest(
          "PATCH",
          "/settings",
          body: jsonEncode(const BridgeSettingUpdate.toolGroup(id: "tasks", enabled: false).toJson()),
        ),
      );

      expect(response.status, 200);
      expect(
        BridgeSettingUpdate.fromJson(jsonDecodeMap(response.body ?? fail("missing body"))),
        const BridgeSettingUpdate.toolGroup(id: "tasks", enabled: false),
      );
      expect(jsonDecodeMap(api.config ?? fail("missing stored settings"))["agentToolGroups"], {
        "disabled": ["tasks"],
      });
      expect(await toolGroups.list(), [
        const BridgeToolGroupSetting(id: "tasks", title: "Fake", summary: "Agents can fake.", enabled: false),
      ]);
    });

    test("PATCH turns agent tools off, keeps each group's own switch, and GET reports it", () async {
      final response = await patchHandler.routeForTest(
        makeRequest(
          "PATCH",
          "/settings",
          body: jsonEncode(const BridgeSettingUpdate.agentTools(enabled: false).toJson()),
        ),
      );

      expect(response.status, 200);
      expect(
        BridgeSettingUpdate.fromJson(jsonDecodeMap(response.body ?? fail("missing body"))),
        const BridgeSettingUpdate.agentTools(enabled: false),
      );
      expect(jsonDecodeMap(api.config ?? fail("missing stored settings"))["agentTools"], isFalse);
      final settings = await GetBridgeSettingsHandler(
        settingsRepository: repository,
        toolGroupSettingsService: toolGroups,
        releaseTrackSettingsService: releaseTrack,
        sleepPreventionService: sleepPrevention,
      ).routeForTest(makeRequest("GET", "/settings"));
      final read = BridgeSettingsResponse.fromJson(jsonDecodeMap(settings.body ?? fail("missing body")));
      expect(read.agentToolsEnabled, isFalse);
      expect(read.toolGroups.single.enabled, isTrue);
    });

    test("PATCH stores the release track and GET reports it", () async {
      final response = await patchHandler.routeForTest(
        makeRequest(
          "PATCH",
          "/settings",
          body: jsonEncode(const BridgeSettingUpdate.releaseTrack(track: BridgeReleaseTrack.internal).toJson()),
        ),
      );

      expect(response.status, 200);
      expect(
        BridgeSettingUpdate.fromJson(jsonDecodeMap(response.body ?? fail("missing body"))),
        const BridgeSettingUpdate.releaseTrack(track: BridgeReleaseTrack.internal),
      );
      expect(jsonDecodeMap(api.config ?? fail("missing stored settings"))["releaseTrack"], "internal");
      final settings = await GetBridgeSettingsHandler(
        settingsRepository: repository,
        toolGroupSettingsService: toolGroups,
        releaseTrackSettingsService: releaseTrack,
        sleepPreventionService: sleepPrevention,
      ).routeForTest(makeRequest("GET", "/settings"));
      expect(
        BridgeSettingsResponse.fromJson(jsonDecodeMap(settings.body ?? fail("missing body"))).releaseTrack,
        BridgeReleaseTrack.internal,
      );
    });

    test("PATCH lets the computer sleep right away and GET reports it", () async {
      wakeLock.isHeld = true;
      final response = await patchHandler.routeForTest(
        makeRequest(
          "PATCH",
          "/settings",
          body: jsonEncode(const BridgeSettingUpdate.preventSleep(enabled: false).toJson()),
        ),
      );

      expect(response.status, 200);
      expect(
        BridgeSettingUpdate.fromJson(jsonDecodeMap(response.body ?? fail("missing body"))),
        const BridgeSettingUpdate.preventSleep(enabled: false),
      );
      expect(wakeLock.isHeld, isFalse);
      expect(jsonDecodeMap(api.config ?? fail("missing stored settings"))["sleepPrevention"], "off");
      final settings = await GetBridgeSettingsHandler(
        settingsRepository: repository,
        toolGroupSettingsService: toolGroups,
        releaseTrackSettingsService: releaseTrack,
        sleepPreventionService: sleepPrevention,
      ).routeForTest(makeRequest("GET", "/settings"));
      expect(
        BridgeSettingsResponse.fromJson(jsonDecodeMap(settings.body ?? fail("missing body"))).preventSleep,
        SleepPreventionStatus.off,
      );
    });

    test("PATCH refuses a release track this bridge does not know and stores nothing", () async {
      final response = await patchHandler.routeForTest(
        makeRequest("PATCH", "/settings", body: jsonEncode(const {"type": "releaseTrack", "track": "beta"})),
      );

      expect(response.status, 400);
      expect(
        BridgeSettingUpdateRejection.fromJson(jsonDecodeMap(response.body ?? fail("missing body"))),
        const BridgeSettingUpdateRejection.unknown(),
      );
      expect(repository.currentSettings.releaseTrack, ReleaseTrack.stable);
    });

    test("GET leaves the release track out on an install that does not update itself", () async {
      final settings = await GetBridgeSettingsHandler(
        settingsRepository: repository,
        toolGroupSettingsService: toolGroups,
        releaseTrackSettingsService: ReleaseTrackSettingsService(settings: repository, updatesItself: false),
        sleepPreventionService: sleepPrevention,
      ).routeForTest(makeRequest("GET", "/settings"));

      final body = jsonDecodeMap(settings.body ?? fail("missing body"));
      expect(body.containsKey("releaseTrack"), isFalse);
    });

    test("PATCH refuses a tool group this bridge does not serve and stores nothing", () async {
      final response = await patchHandler.routeForTest(
        makeRequest(
          "PATCH",
          "/settings",
          body: jsonEncode(const BridgeSettingUpdate.toolGroup(id: "from_a_future_bridge", enabled: false).toJson()),
        ),
      );

      expect(response.status, 400);
      expect(
        BridgeSettingUpdateRejection.fromJson(jsonDecodeMap(response.body ?? fail("missing body"))),
        const BridgeSettingUpdateRejection.unknown(),
      );
      expect(repository.currentSettings.agentToolGroups.disabledIds, isEmpty);
    });
  });
}

class _FakeToolGroup() implements SesoriToolGroup {
  @override
  SesoriToolGroupId get id => SesoriToolGroupIds.tasks;

  @override
  String get title => "Fake";

  @override
  String get summary => "Agents can fake.";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePermissionAutoApprovalService() implements PermissionAutoApprovalService {
  @override
  Future<void> approvePending() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSessionMutationDispatcher() implements SessionMutationDispatcher {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
