import "dart:async";
import "dart:convert";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/pull_request_refresh_settings_api.dart";
import "package:sesori_dart_core/src/capabilities/relay/relay_client.dart";
import "package:sesori_dart_core/src/repositories/models/pull_request_refresh_settings_result.dart";
import "package:sesori_dart_core/src/repositories/pull_request_refresh_settings_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockPullRequestRefreshSettingsApi extends Mock implements PullRequestRefreshSettingsApi {}

void main() {
  late _MockPullRequestRefreshSettingsApi api;
  late PullRequestRefreshSettingsRepository repository;

  setUpAll(() {
    registerFallbackValue(const PullRequestRefreshSettingsRequest(intervalSeconds: 30));
  });

  setUp(() {
    api = _MockPullRequestRefreshSettingsApi();
    repository = PullRequestRefreshSettingsRepository(api: api);
  });

  test("load distinguishes supported, unsupported, and failed responses", () async {
    when(api.getSettings).thenAnswer(
      (_) async => ApiResponse.success(const PullRequestRefreshSettingsResponse(intervalSeconds: 30)),
    );
    expect(await repository.load(), isA<PullRequestRefreshSettingsLoadSupported>());

    when(api.getSettings).thenAnswer(
      (_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null)),
    );
    expect(await repository.load(), isA<PullRequestRefreshSettingsLoadUnsupported>());

    when(api.getSettings).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
    expect(await repository.load(), isA<PullRequestRefreshSettingsLoadFailure>());
  });

  test("update returns the bridge-committed value", () async {
    when(
      () => api.updateSettings(request: any(named: "request")),
    ).thenAnswer(
      (_) async => ApiResponse.success(const PullRequestRefreshSettingsResponse(intervalSeconds: 45)),
    );

    final result = await repository.update(
      request: const PullRequestRefreshSettingsRequest(intervalSeconds: 45),
    );

    expect((result as PullRequestRefreshSettingsMutationCommitted).response.intervalSeconds, 45);
  });

  test("update maps the typed range rejection", () async {
    const rejection = PullRequestRefreshSettingsErrorResponse(
      code: PullRequestRefreshSettingsErrorCode.intervalOutOfRange,
      minimumIntervalSeconds: 15,
      maximumIntervalSeconds: 3600,
    );
    when(
      () => api.updateSettings(request: any(named: "request")),
    ).thenAnswer(
      (_) async => ApiResponse.error(
        ApiError.nonSuccessCode(
          errorCode: 400,
          rawErrorString: jsonEncode(rejection.toJson()),
        ),
      ),
    );

    final result = await repository.update(
      request: const PullRequestRefreshSettingsRequest(intervalSeconds: 10),
    );

    expect((result as PullRequestRefreshSettingsMutationRejected).error, rejection);
  });

  test("update treats post-dispatch response loss as uncertain", () async {
    final errors = <ApiError>[
      ApiError.jsonParsing("not-json"),
      ApiError.emptyResponse(),
      ApiError.dartHttpClient(TimeoutException("timed out")),
      ApiError.dartHttpClient(const RelayResponseLostException(message: "lost")),
    ];

    for (final error in errors) {
      when(
        () => api.updateSettings(request: any(named: "request")),
      ).thenAnswer((_) async => ApiResponse.error(error));

      expect(
        await repository.update(
          request: const PullRequestRefreshSettingsRequest(intervalSeconds: 45),
        ),
        isA<PullRequestRefreshSettingsMutationUncertain>(),
      );
    }
  });
}
