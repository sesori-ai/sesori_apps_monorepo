import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/repositories/models/analytics_delivery_result.dart";
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

class _RecordingAttributionRepository() extends Mock implements AttributionRepository {
  final events = <AttributionEvent>[];
  AnalyticsDeliveryResult result = AnalyticsDeliveryResult.acceptedBySdk;

  @override
  Future<AnalyticsDeliveryResult> logEvent({required AttributionEvent event}) async {
    events.add(event);
    return result;
  }
}

void main() {
  test("enabled runtime sends only the closed installation event", () async {
    final repository = _RecordingAnalyticsRepository();
    final attributionRepository = _RecordingAttributionRepository();
    final service = InstallationAnalyticsService(
      capability: const AnalyticsRuntimeCapability.enabled(),
      repository: repository,
      attributionRepository: attributionRepository,
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
    expect(attributionRepository.events, isEmpty);
  });

  test("disabled runtimes emit no installation event", () async {
    for (final reason in AnalyticsRuntimeDisabledReason.values) {
      final repository = _RecordingAnalyticsRepository();
      final attributionRepository = _RecordingAttributionRepository();
      final service = InstallationAnalyticsService(
        capability: AnalyticsRuntimeCapability.disabled(reason: reason),
        repository: repository,
        attributionRepository: attributionRepository,
      );

      expect(
        await service.loginAttemptStarted(provider: AuthProvider.email),
        AnalyticsDeliveryResult.failed,
      );
      expect(repository.events, isEmpty);
      expect(attributionRepository.events, isEmpty);
    }
  });

  test("sealed auth providers map exhaustively to pinned analytics providers", () async {
    final repository = _RecordingAnalyticsRepository();
    final service = InstallationAnalyticsService(
      capability: const AnalyticsRuntimeCapability.enabled(),
      repository: repository,
      attributionRepository: _RecordingAttributionRepository(),
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

  test("created accounts report registration before login", () async {
    final repository = _RecordingAnalyticsRepository();
    final attributionRepository = _RecordingAttributionRepository();
    final service = InstallationAnalyticsService(
      capability: const AnalyticsRuntimeCapability.enabled(),
      repository: repository,
      attributionRepository: attributionRepository,
    );

    final result = await service.loginAttemptCompleted(
      provider: AuthProvider.google,
      accountStatus: AccountStatus.created,
    );

    expect(result, AnalyticsDeliveryResult.acceptedBySdk);
    expect(repository.events, [
      const InstallationAnalyticsEvent.loginAttemptCompleted(provider: AnalyticsLoginProvider.google),
    ]);
    expect(attributionRepository.events, [
      AttributionEvent.accountCreated,
      AttributionEvent.accountLogin,
    ]);
  });

  test("existing and unknown account statuses report login without registration", () async {
    for (final accountStatus in [AccountStatus.existing, AccountStatus.unknown]) {
      final attributionRepository = _RecordingAttributionRepository();
      final service = InstallationAnalyticsService(
        capability: const AnalyticsRuntimeCapability.enabled(),
        repository: _RecordingAnalyticsRepository(),
        attributionRepository: attributionRepository,
      );

      await service.loginAttemptCompleted(
        provider: AuthProvider.apple,
        accountStatus: accountStatus,
      );

      expect(attributionRepository.events, [AttributionEvent.accountLogin]);
    }
  });

  test("disabled installation analytics does not gate attribution", () async {
    final repository = _RecordingAnalyticsRepository();
    final attributionRepository = _RecordingAttributionRepository();
    final service = InstallationAnalyticsService(
      capability: const AnalyticsRuntimeCapability.disabled(
        reason: AnalyticsRuntimeDisabledReason.recentBuildUnauthenticated,
      ),
      repository: repository,
      attributionRepository: attributionRepository,
    );

    expect(
      await service.loginAttemptCompleted(
        provider: AuthProvider.email,
        accountStatus: AccountStatus.existing,
      ),
      AnalyticsDeliveryResult.failed,
    );
    expect(repository.events, isEmpty);
    expect(attributionRepository.events, [AttributionEvent.accountLogin]);
  });

  test("enabled runtime makes rejected SDK delivery observable", () async {
    final repository = _RecordingAnalyticsRepository()..result = AnalyticsDeliveryResult.failed;
    final service = InstallationAnalyticsService(
      capability: const AnalyticsRuntimeCapability.enabled(),
      repository: repository,
      attributionRepository: _RecordingAttributionRepository(),
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
