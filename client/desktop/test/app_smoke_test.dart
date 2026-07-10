import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/app.dart";
import "package:sesori_desktop/core/di/injection.dart";

class _InMemorySecureStorage implements SecureStorage {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> write({required String key, required String value}) async => _values[key] = value;

  @override
  Future<void> delete({required String key}) async => _values.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets("cold start with no session lands on the login view", (WidgetTester tester) async {
    configureDesktopDependencies();
    // The secure-storage plugin has no platform channel under flutter_test;
    // swap in an in-memory fake so the gate's local-session check completes.
    getIt.unregister<SecureStorage>();
    getIt.registerLazySingleton<SecureStorage>(_InMemorySecureStorage.new);

    await tester.pumpWidget(const SesoriDesktopApp());
    await tester.pump();
    await tester.pump();

    expect(find.text("Continue with GitHub"), findsOneWidget);
    expect(find.text("Continue with Google"), findsOneWidget);
  });
}
