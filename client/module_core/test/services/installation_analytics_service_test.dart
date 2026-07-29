import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class _RecordingInstallationRepository extends Mock implements InstallationAnalyticsRepository {
  final events = <InstallationAnalyticsEvent>[];

  @override
  Future<AnalyticsDeliveryResult> logEvent({required InstallationAnalyticsEvent event}) async {
    events.add(event);
    return AnalyticsDeliveryResult.acceptedBySdk;
  }
}

void main() {
  test("enabled runtime sends only the closed installation event", () async {
    final repository = _RecordingInstallationRepository();
    final service = InstallationAnalyticsService(
      capability: const AnalyticsRuntimeCapability.enabled(),
      repository: repository,
    );

    final result = await service.loginAttemptFailed(
      provider: AnalyticsLoginProvider.google,
      failureKind: AnalyticsLoginFailureKind.timeout,
    );

    expect(result, AnalyticsDeliveryResult.acceptedBySdk);
    expect(repository.events, [
      const InstallationAnalyticsEvent.loginAttemptFailed(
        provider: AnalyticsLoginProvider.google,
        failureKind: AnalyticsLoginFailureKind.timeout,
      ),
    ]);
    expect(repository.events.single.parameters, isNot(contains("user_key")));
  });

  test("debug, unsupported, and legacy-clear-failed runtimes emit nothing", () async {
    for (final reason in [
      AnalyticsRuntimeDisabledReason.debugOrProfile,
      AnalyticsRuntimeDisabledReason.unsupportedPlatform,
      AnalyticsRuntimeDisabledReason.legacyIdentityClearFailed,
    ]) {
      final repository = _RecordingInstallationRepository();
      final service = InstallationAnalyticsService(
        capability: AnalyticsRuntimeCapability.disabled(reason: reason),
        repository: repository,
      );

      expect(
        await service.loginAttemptStarted(provider: AnalyticsLoginProvider.email),
        AnalyticsDeliveryResult.failed,
      );
      expect(repository.events, isEmpty);
    }
  });
}
