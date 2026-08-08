import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("pull request refresh settings contracts", () {
    test("response round trips", () {
      const response = PullRequestRefreshSettingsResponse(intervalSeconds: 45);

      expect(PullRequestRefreshSettingsResponse.fromJson(response.toJson()), response);
    });

    test("interval rejects missing, null, non-numeric, and fractional values", () {
      for (final json in <Map<String, dynamic>>[
        const {},
        const {"intervalSeconds": null},
        const {"intervalSeconds": "45"},
        const {"intervalSeconds": 45.5},
      ]) {
        expect(() => PullRequestRefreshSettingsResponse.fromJson(json), throwsFormatException);
      }
    });
  });
}
