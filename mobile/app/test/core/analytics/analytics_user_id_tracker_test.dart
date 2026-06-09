import "dart:convert";

import "package:crypto/crypto.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/analytics/analytics_user_id_tracker.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../helpers/test_helpers.dart";

void main() {
  late MockAuthSession mockAuthSession;
  late MockFirebaseAnalytics mockAnalytics;
  late BehaviorSubject<AuthState> authStateSubject;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    mockAuthSession = MockAuthSession();
    mockAnalytics = MockFirebaseAnalytics();
    authStateSubject = BehaviorSubject<AuthState>.seeded(const AuthState.initial());

    when(() => mockAuthSession.authStateStream).thenAnswer((_) => authStateSubject.stream);
    when(() => mockAnalytics.setUserId(id: any(named: "id"))).thenAnswer((_) async {});
  });

  tearDown(() async {
    await authStateSubject.close();
  });

  group("AnalyticsUserIdTracker", () {
    test("sets hashed user ID when auth state is authenticated", () async {
      const user = AuthUser(
        id: "user-abc-123",
        provider: AuthProvider.github,
        providerUserId: "gh-123",
        providerUsername: "testuser",
      );
      authStateSubject.add(const AuthState.authenticated(user: user));

      AnalyticsUserIdTracker(
        authSession: mockAuthSession,
        analytics: mockAnalytics,
      );

      await Future<void>.delayed(Duration.zero);

      final expectedHash = sha256.convert(utf8.encode(user.id)).toString();
      verify(() => mockAnalytics.setUserId(id: expectedHash)).called(1);
    });

    test("clears user ID when auth state becomes unauthenticated", () async {
      authStateSubject.add(const AuthState.authenticated(user: AuthUser(
        id: "user-1",
        provider: AuthProvider.github,
        providerUserId: "gh-1",
        providerUsername: "test",
      )));

      final tracker = AnalyticsUserIdTracker(
        authSession: mockAuthSession,
        analytics: mockAnalytics,
      );

      await Future<void>.delayed(Duration.zero);

      authStateSubject.add(const AuthState.unauthenticated());
      await Future<void>.delayed(Duration.zero);

      verify(() => mockAnalytics.setUserId(id: null)).called(1);
      await tracker.dispose();
    });

    test("clears user ID for failed state, does nothing for initial and authenticating", () async {
      final tracker = AnalyticsUserIdTracker(
        authSession: mockAuthSession,
        analytics: mockAnalytics,
      );

      await Future<void>.delayed(Duration.zero);

      authStateSubject.add(const AuthState.authenticating());
      await Future<void>.delayed(Duration.zero);

      authStateSubject.add(const AuthState.failed(error: "oops"));
      await Future<void>.delayed(Duration.zero);

      // Called once for the failed state; initial and authenticating are no-ops.
      verify(() => mockAnalytics.setUserId(id: null)).called(1);
      await tracker.dispose();
    });

    test("reacts to initial stream value on creation", () async {
      const user = AuthUser(
        id: "initial-user",
        provider: AuthProvider.google,
        providerUserId: "google-1",
        providerUsername: "initial",
      );
      await authStateSubject.close();
      authStateSubject = BehaviorSubject<AuthState>.seeded(const AuthState.authenticated(user: user));
      when(() => mockAuthSession.authStateStream).thenAnswer((_) => authStateSubject.stream);

      AnalyticsUserIdTracker(
        authSession: mockAuthSession,
        analytics: mockAnalytics,
      );

      await Future<void>.delayed(Duration.zero);

      final expectedHash = sha256.convert(utf8.encode(user.id)).toString();
      verify(() => mockAnalytics.setUserId(id: expectedHash)).called(1);
    });

    test("produces same hash for same user ID across multiple devices", () async {
      const userId = "cross-device-user-42";
      const user = AuthUser(
        id: userId,
        provider: AuthProvider.github,
        providerUserId: "gh-42",
        providerUsername: "cross",
      );
      authStateSubject.add(const AuthState.authenticated(user: user));

      AnalyticsUserIdTracker(
        authSession: mockAuthSession,
        analytics: mockAnalytics,
      );

      await Future<void>.delayed(Duration.zero);

      final captured = verify(() => mockAnalytics.setUserId(id: captureAny(named: "id"))).captured.single as String;
      final expectedHash = sha256.convert(utf8.encode(userId)).toString();

      expect(captured, expectedHash);
    });

    test("dispose cancels subscription", () async {
      final tracker = AnalyticsUserIdTracker(
        authSession: mockAuthSession,
        analytics: mockAnalytics,
      );

      await tracker.dispose();

      authStateSubject.add(const AuthState.authenticated(user: AuthUser(
        id: "after-dispose",
        provider: AuthProvider.github,
        providerUserId: "gh-99",
        providerUsername: "late",
      )));
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => mockAnalytics.setUserId(id: any(named: "id")));
    });

    test("swallows analytics errors without crashing", () async {
      when(() => mockAnalytics.setUserId(id: any(named: "id"))).thenThrow(Exception("analytics crashed"));

      authStateSubject.add(const AuthState.authenticated(user: AuthUser(
        id: "user-1",
        provider: AuthProvider.github,
        providerUserId: "gh-1",
        providerUsername: "test",
      )));

      AnalyticsUserIdTracker(
        authSession: mockAuthSession,
        analytics: mockAnalytics,
      );

      await Future<void>.delayed(Duration.zero);

      // Test passes if no exception is thrown.
      verify(() => mockAnalytics.setUserId(id: any(named: "id"))).called(1);
    });

    test("processes auth events sequentially with asyncMap", () async {
      final events = <String>[];

      when(() => mockAnalytics.setUserId(id: any(named: "id"))).thenAnswer((invocation) async {
        final id = invocation.namedArguments[#id] as String?;
        events.add(id ?? "null");
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });

      authStateSubject.add(const AuthState.authenticated(user: AuthUser(
        id: "user-1",
        provider: AuthProvider.github,
        providerUserId: "gh-1",
        providerUsername: "test",
      )));

      final tracker = AnalyticsUserIdTracker(
        authSession: mockAuthSession,
        analytics: mockAnalytics,
      );

      await Future<void>.delayed(Duration.zero);

      authStateSubject.add(const AuthState.unauthenticated());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Events should be processed in order: set hash first, then clear.
      expect(events, [hasLength(greaterThan(0)), "null"]);
      await tracker.dispose();
    });
  });
}
