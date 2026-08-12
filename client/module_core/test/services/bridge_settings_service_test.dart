import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/repositories/bridge_settings_repository.dart";
import "package:sesori_dart_core/src/repositories/models/bridge_settings_result.dart";
import "package:sesori_dart_core/src/services/bridge_settings_service.dart";
import "package:test/test.dart";

class _MockBridgeSettingsRepository extends Mock implements BridgeSettingsRepository;

void main() {
  late _MockBridgeSettingsRepository repository;
  late BridgeSettingsService service;

  setUp(() {
    repository = _MockBridgeSettingsRepository();
    service = BridgeSettingsService(repository: repository);
  });

  test("plans trimmed integer seconds inside the supported range", () {
    final plan = service.planPullRequestRefreshUpdate(input: " 45 ", bounds: null);

    expect((plan as PullRequestRefreshSettingsUpdateRequest).intervalSeconds, 45);
  });

  test("accepts any whole number until the bridge reports bounds", () {
    expect(
      service.planPullRequestRefreshUpdate(input: "14", bounds: null),
      isA<PullRequestRefreshSettingsUpdateRequest>(),
    );
    expect(
      service.planPullRequestRefreshUpdate(input: "3601", bounds: null),
      isA<PullRequestRefreshSettingsUpdateRequest>(),
    );
  });

  test("rejects non-positive intervals before the bridge reports bounds", () {
    expect(
      service.planPullRequestRefreshUpdate(input: "0", bounds: null),
      isA<PullRequestRefreshSettingsUpdateInvalid>(),
    );
    expect(
      service.planPullRequestRefreshUpdate(input: "-30", bounds: null),
      isA<PullRequestRefreshSettingsUpdateInvalid>(),
    );
  });

  test("rejects malformed input and values outside bridge-reported bounds", () {
    final bounds = PullRequestRefreshSettingsBounds(minimumIntervalSeconds: 20, maximumIntervalSeconds: 1800);
    for (final input in ["", "15.5", "19", "1801"]) {
      expect(
        service.planPullRequestRefreshUpdate(input: input, bounds: bounds),
        isA<PullRequestRefreshSettingsUpdateInvalid>(),
      );
    }
    expect(
      service.planPullRequestRefreshUpdate(input: "20", bounds: bounds),
      isA<PullRequestRefreshSettingsUpdateRequest>(),
    );
    expect(
      service.planPullRequestRefreshUpdate(input: "1800", bounds: bounds),
      isA<PullRequestRefreshSettingsUpdateRequest>(),
    );
  });
}
