import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("pull request refresh settings contracts", () {
    test("request and response round trip", () {
      const request = PullRequestRefreshSettingsRequest(intervalSeconds: 45);
      const response = PullRequestRefreshSettingsResponse(intervalSeconds: 45);

      expect(PullRequestRefreshSettingsRequest.fromJson(request.toJson()), request);
      expect(PullRequestRefreshSettingsResponse.fromJson(response.toJson()), response);
    });

    test("integer fields reject missing, null, non-numeric, and fractional values", () {
      for (final json in <Map<String, dynamic>>[
        const {},
        const {"intervalSeconds": null},
        const {"intervalSeconds": "45"},
        const {"intervalSeconds": 45.5},
      ]) {
        expect(() => PullRequestRefreshSettingsRequest.fromJson(json), throwsFormatException);
        expect(() => PullRequestRefreshSettingsResponse.fromJson(json), throwsFormatException);
      }

      for (final field in ["minimumIntervalSeconds", "maximumIntervalSeconds"]) {
        expect(
          () => PullRequestRefreshSettingsErrorResponse.fromJson({
            "code": "intervalOutOfRange",
            "minimumIntervalSeconds": 15,
            "maximumIntervalSeconds": 3600,
            field: 15.5,
          }),
          throwsFormatException,
        );
      }
    });

    test("typed error round trips and unknown codes degrade", () {
      const error = PullRequestRefreshSettingsErrorResponse(
        code: PullRequestRefreshSettingsErrorCode.intervalOutOfRange,
        minimumIntervalSeconds: 15,
        maximumIntervalSeconds: 3600,
      );

      expect(PullRequestRefreshSettingsErrorResponse.fromJson(error.toJson()), error);
      expect(
        PullRequestRefreshSettingsErrorResponse.fromJson({
          ...error.toJson(),
          "code": "futureCode",
        }).code,
        PullRequestRefreshSettingsErrorCode.unknown,
      );
    });
  });
}
