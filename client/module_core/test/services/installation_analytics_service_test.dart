import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class _RecordingAnalyticsRepository() extends Mock implements AnalyticsRepository {
  final events = <InstallationAnalyticsEvent>[];
  AnalyticsDeliveryResult result = AnalyticsDeliveryResult.acceptedBySdk;

  @override
  Future<AnalyticsDeliveryResult> logInstallationEvent({required InstallationAnalyticsEvent event}) async {
    events.add(event);
    return result;
  }
}

void main() {
  test("enabled runtime sends only the closed installation event", () async {
    final repository = _RecordingAnalyticsRepository();
    final service = InstallationAnalyticsService(
      capability: const AnalyticsRuntimeCapability.enabled(),
      repository: repository,
    );

    final result = await service.loginAttemptFailed(
      provider: AuthProvider.google,
      cause: LoginAttemptFailureCause.timeout,
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

  test("disabled runtimes emit nothing", () async {
    for (final reason in [
      AnalyticsRuntimeDisabledReason.debugOrProfile,
      AnalyticsRuntimeDisabledReason.automatedTestEnvironment,
      AnalyticsRuntimeDisabledReason.unsupportedPlatform,
      AnalyticsRuntimeDisabledReason.analyticsSinkUnavailable,
      AnalyticsRuntimeDisabledReason.identitySafetyPreconditionFailed,
    ]) {
      final repository = _RecordingAnalyticsRepository();
      final service = InstallationAnalyticsService(
        capability: AnalyticsRuntimeCapability.disabled(reason: reason),
        repository: repository,
      );

      expect(
        await service.loginAttemptStarted(provider: AuthProvider.email),
        AnalyticsDeliveryResult.failed,
      );
      expect(repository.events, isEmpty);
    }
  });

  test("sealed auth providers map exhaustively to pinned analytics providers", () async {
    final repository = _RecordingAnalyticsRepository();
    final service = InstallationAnalyticsService(
      capability: const AnalyticsRuntimeCapability.enabled(),
      repository: repository,
    );

    for (final provider in [
      AuthProvider.github,
      AuthProvider.google,
      AuthProvider.apple,
      AuthProvider.email,
    ]) {
      await service.loginAttemptStarted(provider: provider);
    }

    expect(
      repository.events.map((event) => event.parameters["provider"]),
      ["github", "google", "apple", "email"],
    );
  });

  test("enabled runtime makes rejected SDK delivery observable", () async {
    final repository = _RecordingAnalyticsRepository()..result = AnalyticsDeliveryResult.failed;
    final service = InstallationAnalyticsService(
      capability: const AnalyticsRuntimeCapability.enabled(),
      repository: repository,
    );
    final logLines = <String>[];

    await runZoned(
      () => service.loginAttemptStarted(provider: AuthProvider.github),
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, line) => logLines.add(line),
      ),
    );

    expect(logLines, contains("Failed to report installation analytics event"));
  });
}
