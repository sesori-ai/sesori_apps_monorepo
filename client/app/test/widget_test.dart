import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/di/analytics_runtime_bootstrap.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_mobile/main.dart";
import "package:sesori_persistence/sesori_persistence.dart";

import "helpers/test_helpers.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllFallbackValues);

  setUp(() async {
    await configureDependencies(
      scope: PersistenceScope.development,
      firebaseEnabled: false,
      createAnalyticsRuntimeBootstrap: ({required crawlGateService}) async => AnalyticsRuntimeBootstrap(
        capability: const AnalyticsRuntimeCapability.disabled(
          reason: AnalyticsRuntimeDisabledReason.analyticsSinkUnavailable,
        ),
        crawlGate: Future.value(AnalyticsStoreCrawlGate.allow),
      ),
    );
    final statusStream = BehaviorSubject<ConnectionStatus>.seeded(
      const ConnectionStatus.disconnected(),
    );
    final mockConnectionService = MockConnectionService();
    when(() => mockConnectionService.status).thenAnswer((_) => statusStream.stream);
    when(() => mockConnectionService.currentStatus).thenReturn(
      const ConnectionDisconnected(),
    );
    if (getIt.isRegistered<ConnectionService>()) {
      getIt.unregister<ConnectionService>();
    }
    getIt.registerLazySingleton<ConnectionService>(() => mockConnectionService);

    final mockAuthSession = MockAuthSession();
    when(mockAuthSession.restoreSession).thenAnswer((_) async => false);
    if (getIt.isRegistered<AuthSession>()) {
      getIt.unregister<AuthSession>();
    }
    getIt.registerLazySingleton<AuthSession>(() => mockAuthSession);
  });

  tearDown(() async {
    await getIt.reset();
  });

  test("SesoriApp can be instantiated", () {
    expect(
      const SesoriApp(initialAppearance: AppearanceMode.system, initialChatInputMode: ChatInputMode.voiceFirst),
      isA<SesoriApp>(),
    );
  });
}
