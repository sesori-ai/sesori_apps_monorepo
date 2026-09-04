import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("BridgeSettingsResponse serializes every bridge setting", () {
    const response = BridgeSettingsResponse(
      pullRequestRefresh: PullRequestRefreshSettingsResponse(intervalSeconds: 45),
      yolo: YoloSettingsResponse(enabled: true),
      warmUpPluginsOnSessionOpen: true,
    );

    expect(response.toJson(), {
      "pullRequestRefresh": {"intervalSeconds": 45},
      "yolo": {"enabled": true},
      "warmUpPluginsOnSessionOpen": true,
    });
    expect(BridgeSettingsResponse.fromJson(response.toJson()), response);
  });

  test("BridgeSettingsResponse keeps session-open warm-up nullable for older bridges", () {
    final response = BridgeSettingsResponse.fromJson(const {
      "pullRequestRefresh": {"intervalSeconds": 30},
      "yolo": {"enabled": false},
    });

    expect(response.warmUpPluginsOnSessionOpen, isNull);
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
