import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/repositories/models/pull_request_refresh_settings_result.dart";
import "package:sesori_dart_core/src/repositories/pull_request_refresh_settings_repository.dart";
import "package:sesori_dart_core/src/services/pull_request_refresh_settings_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockPullRequestRefreshSettingsRepository extends Mock implements PullRequestRefreshSettingsRepository {}

void main() {
  late _MockPullRequestRefreshSettingsRepository repository;
  late PullRequestRefreshSettingsService service;

  setUpAll(() {
    registerFallbackValue(const PullRequestRefreshSettingsRequest(intervalSeconds: 30));
  });

  setUp(() {
    repository = _MockPullRequestRefreshSettingsRepository();
    service = PullRequestRefreshSettingsService(repository: repository);
  });

  test("plans trimmed integer seconds inside the supported range", () {
    final plan = service.planUpdate(input: " 45 ");

    expect((plan as PullRequestRefreshSettingsUpdateRequest).request.intervalSeconds, 45);
  });

  test("rejects non-integers and values outside 15 through 3600", () {
    for (final input in ["", "15.5", "14", "3601"]) {
      expect(service.planUpdate(input: input), isA<PullRequestRefreshSettingsUpdateInvalid>());
    }
    expect(service.planUpdate(input: "15"), isA<PullRequestRefreshSettingsUpdateRequest>());
    expect(service.planUpdate(input: "3600"), isA<PullRequestRefreshSettingsUpdateRequest>());
  });

  test("delegates loading and mutation to the repository", () async {
    when(repository.load).thenAnswer(
      (_) async => const PullRequestRefreshSettingsLoadSupported(
        response: PullRequestRefreshSettingsResponse(intervalSeconds: 30),
      ),
    );
    when(
      () => repository.update(request: any(named: "request")),
    ).thenAnswer(
      (_) async => const PullRequestRefreshSettingsMutationCommitted(
        response: PullRequestRefreshSettingsResponse(intervalSeconds: 45),
      ),
    );

    await service.load();
    await service.update(request: const PullRequestRefreshSettingsRequest(intervalSeconds: 45));

    verify(repository.load).called(1);
    verify(
      () => repository.update(request: const PullRequestRefreshSettingsRequest(intervalSeconds: 45)),
    ).called(1);
  });
}
