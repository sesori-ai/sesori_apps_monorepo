import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("BridgeSettingsResponse serializes every bridge setting", () {
    const response = BridgeSettingsResponse(
      pullRequestRefresh: PullRequestRefreshSettingsResponse(intervalSeconds: 45),
      yolo: YoloSettingsResponse(enabled: true),
      warmUpPluginsOnSessionOpen: true,
      agentToolsEnabled: false,
      toolGroups: [
        BridgeToolGroupSetting(id: "tasks", title: "Scheduled tasks", summary: "Read tasks.", enabled: false),
      ],
      releaseTrack: BridgeReleaseTrack.internal,
      preventSleep: true,
    );

    expect(response.toJson(), {
      "pullRequestRefresh": {"intervalSeconds": 45},
      "yolo": {"enabled": true, "supportsSessionOverride": false},
      "warmUpPluginsOnSessionOpen": true,
      "agentToolsEnabled": false,
      "toolGroups": [
        {"id": "tasks", "title": "Scheduled tasks", "summary": "Read tasks.", "enabled": false},
      ],
      "releaseTrack": "internal",
      "preventSleep": true,
    });
    expect(BridgeSettingsResponse.fromJson(response.toJson()), response);
  });

  test("BridgeSettingsResponse keeps session-open warm-up nullable for older bridges", () {
    final response = BridgeSettingsResponse.fromJson(const {
      "pullRequestRefresh": {"intervalSeconds": 30},
      "yolo": {"enabled": false},
    });

    expect(response.warmUpPluginsOnSessionOpen, isNull);
    expect(response.agentToolsEnabled, isNull);
    expect(response.toolGroups, isEmpty);
    expect(response.releaseTrack, isNull);
    expect(response.preventSleep, isNull);
  });

  test("BridgeSettingsResponse reads a release track it does not know as unknown", () {
    final response = BridgeSettingsResponse.fromJson(const {
      "yolo": {"enabled": false},
      "releaseTrack": "beta",
    });

    expect(response.releaseTrack, BridgeReleaseTrack.unknown);
  });

  test("BridgeSettingsResponse accepts a bridge that omits the pull request interval", () {
    final response = BridgeSettingsResponse.fromJson(const {
      "yolo": {"enabled": true},
      "warmUpPluginsOnSessionOpen": false,
    });

    expect(response.pullRequestRefresh, isNull);
    expect(response.yolo.enabled, isTrue);
  });

  test("BridgeSettingsResponse rejects a missing nested setting", () {
    expect(
      () => BridgeSettingsResponse.fromJson(const {
        "pullRequestRefresh": {"intervalSeconds": 30},
      }),
      throwsA(isA<TypeError>()),
    );
  });
}
