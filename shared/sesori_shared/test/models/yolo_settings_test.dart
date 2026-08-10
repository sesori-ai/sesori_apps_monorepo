import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("YoloSettingsResponse round trips", () {
    const response = YoloSettingsResponse(enabled: true);

    expect(response.toJson(), {"enabled": true});
    expect(YoloSettingsResponse.fromJson(response.toJson()), response);
  });
}
