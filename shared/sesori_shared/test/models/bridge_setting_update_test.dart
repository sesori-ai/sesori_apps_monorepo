import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("BridgeSettingUpdate", () {
    test("cadence variant round trips with its discriminator", () {
      const update = BridgeSettingUpdate.pullRequestRefreshInterval(intervalSeconds: 45);

      expect(
        update.toJson(),
        {"type": "pullRequestRefreshInterval", "intervalSeconds": 45},
      );
      expect(BridgeSettingUpdate.fromJson(update.toJson()), update);
    });

    test("cadence interval rejects missing, null, non-numeric, and fractional values", () {
      for (final intervalSeconds in <Object?>[null, "45", 45.5]) {
        expect(
          () => BridgeSettingUpdate.fromJson({
            "type": "pullRequestRefreshInterval",
            "intervalSeconds": intervalSeconds,
          }),
          throwsFormatException,
        );
      }
      expect(
        () => BridgeSettingUpdate.fromJson(const {"type": "pullRequestRefreshInterval"}),
        throwsFormatException,
      );
    });

    test("unknown setting types degrade to an explicit variant", () {
      expect(
        BridgeSettingUpdate.fromJson(const {"type": "futureSetting", "enabled": true}),
        const BridgeSettingUpdate.unknown(),
      );
    });
  });

  group("BridgeSettingUpdateRejection", () {
    test("cadence range rejection round trips with its discriminator", () {
      const rejection = BridgeSettingUpdateRejection.pullRequestRefreshIntervalOutOfRange(
        minimumIntervalSeconds: 15,
        maximumIntervalSeconds: 3600,
      );

      expect(
        rejection.toJson(),
        {
          "type": "pullRequestRefreshIntervalOutOfRange",
          "minimumIntervalSeconds": 15,
          "maximumIntervalSeconds": 3600,
        },
      );
      expect(BridgeSettingUpdateRejection.fromJson(rejection.toJson()), rejection);
    });

    test("range fields reject non-integer values", () {
      for (final field in ["minimumIntervalSeconds", "maximumIntervalSeconds"]) {
        expect(
          () => BridgeSettingUpdateRejection.fromJson({
            "type": "pullRequestRefreshIntervalOutOfRange",
            "minimumIntervalSeconds": 15,
            "maximumIntervalSeconds": 3600,
            field: 15.5,
          }),
          throwsFormatException,
        );
      }
    });

    test("unknown rejection types degrade to an explicit variant", () {
      expect(
        BridgeSettingUpdateRejection.fromJson(const {"type": "futureRejection"}),
        const BridgeSettingUpdateRejection.unknown(),
      );
    });
  });
}
