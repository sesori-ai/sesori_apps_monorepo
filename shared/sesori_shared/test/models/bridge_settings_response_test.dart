import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("BridgeSettingsResponse serializes both required settings", () {
    const response = BridgeSettingsResponse(
      pullRequestRefresh: PullRequestRefreshSettingsResponse(intervalSeconds: 45),
      yolo: YoloSettingsResponse(enabled: true),
    );

    expect(response.toJson(), {
      "pullRequestRefresh": {"intervalSeconds": 45},
      "yolo": {"enabled": true},
    });
    expect(BridgeSettingsResponse.fromJson(response.toJson()), response);
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
