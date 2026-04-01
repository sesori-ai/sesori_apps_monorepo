// ignore_for_file: unnecessary_lambdas

import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_mobile/main.dart";

import "helpers/test_helpers.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllFallbackValues);

  setUp(() {
    final mockStorage = MockFlutterSecureStorage();
    when(() => mockStorage.read(key: "access_token")).thenAnswer((_) async => null);
    when(() => mockStorage.read(key: "refresh_token")).thenAnswer((_) async => null);
    when(() => mockStorage.read(key: "pkce_verifier")).thenAnswer((_) async => null);
    when(() => mockStorage.read(key: "oauth_provider")).thenAnswer((_) async => null);
    when(() => mockStorage.read(key: "relay_room_key")).thenAnswer((_) async => null);

    configureDependencies();
    getIt.unregister<FlutterSecureStorage>();
    getIt.registerLazySingleton<FlutterSecureStorage>(() => mockStorage);
    getIt.unregister<FirebaseCrashlytics>();
    getIt.registerLazySingleton<FirebaseCrashlytics>(() => MockFirebaseCrashlytics());

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
    expect(const SesoriApp(), isA<SesoriApp>());
  });
}
