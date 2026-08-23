import "package:sesori_dart_core/src/repositories/models/bridge_settings_result.dart";
import "package:test/test.dart";

void main() {
  group("PullRequestRefreshSettingsUpdatePlan", () {
    test("accepts trimmed positive integer seconds before bounds are known", () {
      for (final input in ["14", " 45 ", "3601"]) {
        expect(
          PullRequestRefreshSettingsUpdatePlan.parse(input: input, bounds: null),
          isA<PullRequestRefreshSettingsUpdateRequest>(),
        );
      }
    });

    test("rejects malformed and non-positive input before bounds are known", () {
      for (final input in ["", "15.5", "0", "-30"]) {
        expect(
          PullRequestRefreshSettingsUpdatePlan.parse(input: input, bounds: null),
          isA<PullRequestRefreshSettingsUpdateInvalid>(),
        );
      }
    });

    test("applies bridge-reported bounds", () {
      final bounds = PullRequestRefreshSettingsBounds(
        minimumIntervalSeconds: 20,
        maximumIntervalSeconds: 1800,
      );

      for (final input in ["19", "1801"]) {
        expect(
          PullRequestRefreshSettingsUpdatePlan.parse(input: input, bounds: bounds),
          isA<PullRequestRefreshSettingsUpdateInvalid>(),
        );
      }
      for (final input in ["20", "1800"]) {
        expect(
          PullRequestRefreshSettingsUpdatePlan.parse(input: input, bounds: bounds),
          isA<PullRequestRefreshSettingsUpdateRequest>(),
        );
      }
    });
  });
}
