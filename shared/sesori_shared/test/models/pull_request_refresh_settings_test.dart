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

    test("request rejects a non-integer number", () {
      expect(
        () => PullRequestRefreshSettingsRequest.fromJson({"intervalSeconds": 45.5}),
        throwsFormatException,
      );
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
