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

  setUp(() {
    repository = _MockPullRequestRefreshSettingsRepository();
    service = PullRequestRefreshSettingsService(repository: repository);
  });

  test("plans trimmed integer seconds inside the supported range", () {
    final plan = service.planUpdate(input: " 45 ", bounds: null);

    expect((plan as PullRequestRefreshSettingsUpdateRequest).intervalSeconds, 45);
  });

  test("accepts any whole number until the bridge reports bounds", () {
    expect(service.planUpdate(input: "14", bounds: null), isA<PullRequestRefreshSettingsUpdateRequest>());
    expect(service.planUpdate(input: "3601", bounds: null), isA<PullRequestRefreshSettingsUpdateRequest>());
  });

  test("rejects non-positive intervals before the bridge reports bounds", () {
    expect(service.planUpdate(input: "0", bounds: null), isA<PullRequestRefreshSettingsUpdateInvalid>());
    expect(service.planUpdate(input: "-30", bounds: null), isA<PullRequestRefreshSettingsUpdateInvalid>());
  });

  test("rejects malformed input and values outside bridge-reported bounds", () {
    final bounds = PullRequestRefreshSettingsBounds(minimumIntervalSeconds: 20, maximumIntervalSeconds: 1800);
    for (final input in ["", "15.5", "19", "1801"]) {
      expect(
        service.planUpdate(input: input, bounds: bounds),
        isA<PullRequestRefreshSettingsUpdateInvalid>(),
      );
    }
    expect(service.planUpdate(input: "20", bounds: bounds), isA<PullRequestRefreshSettingsUpdateRequest>());
    expect(service.planUpdate(input: "1800", bounds: bounds), isA<PullRequestRefreshSettingsUpdateRequest>());
  });

  test("delegates loading and mutation to the repository", () async {
    when(repository.load).thenAnswer(
      (_) async => const PullRequestRefreshSettingsLoadSupported(
        response: PullRequestRefreshSettingsResponse(intervalSeconds: 30),
      ),
    );
    when(
      () => repository.update(intervalSeconds: any(named: "intervalSeconds")),
    ).thenAnswer(
      (_) async => const PullRequestRefreshSettingsMutationCommitted(
        response: PullRequestRefreshSettingsResponse(intervalSeconds: 45),
      ),
    );

    await service.load();
    await service.update(intervalSeconds: 45);

    verify(repository.load).called(1);
    verify(() => repository.update(intervalSeconds: 45)).called(1);
  });
}
