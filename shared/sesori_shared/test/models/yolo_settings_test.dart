import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("YoloSettingsResponse round trips", () {
    const response = YoloSettingsResponse(enabled: true, supportsSessionOverride: true);

    expect(response.toJson(), {"enabled": true, "supportsSessionOverride": true});
    expect(YoloSettingsResponse.fromJson(response.toJson()), response);
  });

  test("a bridge that omits supportsSessionOverride offers no per-session choice", () {
    expect(YoloSettingsResponse.fromJson(const {"enabled": false}).supportsSessionOverride, isFalse);
  });
}
