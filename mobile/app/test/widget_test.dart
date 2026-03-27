// ignore_for_file: unnecessary_lambdas

import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_mobile/main.dart";

import "helpers/test_helpers.dart";

void main() {
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
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets("App renders login screen on startup", (WidgetTester tester) async {
    await tester.pumpWidget(const SesoriApp());
    await tester.pumpAndSettle();

    // The app now starts on the login screen (auth-first flow).
    expect(find.text("Sesori Mobile"), findsOneWidget);
    expect(find.text("Sign in with GitHub"), findsOneWidget);
  });
}
