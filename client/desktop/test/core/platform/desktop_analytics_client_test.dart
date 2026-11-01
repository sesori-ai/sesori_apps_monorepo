import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/platform/desktop_analytics_client.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";

const _userA = AuthUser(id: "user-a", provider: AuthProvider.github, providerUserId: "a", providerUsername: "alpha");
const _userB = AuthUser(id: "user-b", provider: AuthProvider.github, providerUserId: "b", providerUsername: "beta");
const _userKey = "user-key-that-must-not-be-sent";
const _identity = DesktopBundleIdentity(
  version: "1.11.0",
  buildNumber: 1066,
  sourceSha: "source-sha",
  os: DesktopBundleOs.macos,
  architecture: DesktopBundleArchitecture.arm64,
);

class _MockAuthSession() extends Mock implements AuthSession;

class _MockBundleSource() extends Mock implements InstalledDesktopBundleSource;

class _FakeEventApi() implements ProductAnalyticsEventApi {
  final List<({String userId, ProductAnalyticsEventRequest request})> attempts = [];
  Future<ApiResponse<bool>>? never;
  Object? thrown;

  @override
  Future<ApiResponse<bool>> send({required String userId, required ProductAnalyticsEventRequest request}) async {
    attempts.add((userId: userId, request: request));
    final thrown = this.thrown;
    if (thrown != null) throw thrown;
    final pending = never;
    if (pending != null) return await pending;
    return ApiResponse.success(true);
  }
}

void main() {
  late _MockAuthSession authSession;
  late _MockBundleSource bundleSource;
  late DesktopAnalyticsClient client;

  DesktopProductAnalyticsDeliveryService serviceFor({required _FakeEventApi api}) =>
      DesktopProductAnalyticsDeliveryService(
        eventSource: client,
        repository: ProductAnalyticsEventRepository(api: api),
        authSession: authSession,
        bundleSource: bundleSource,
      );

  Future<void> log({required ProductAnalyticsEvent event}) => client.logProductEvent(
    envelope: ProductAnalyticsEnvelope(event: event, occurredAtUtc: DateTime.utc(2026, 10, 31)),
    userKey: _userKey,
  );

  Future<void> logAnswered() => log(event: const ProductAnalyticsEvent.sessionQuestionAnswered());

  Future<void> logRejected() => log(event: const ProductAnalyticsEvent.sessionQuestionRejected());

  Future<void> logAborted() => log(event: const ProductAnalyticsEvent.sessionAbortSucceeded());

  setUp(() {
    authSession = _MockAuthSession();
    when(() => authSession.currentState).thenReturn(const AuthState.authenticated(user: _userA));
    bundleSource = _MockBundleSource();
    when(() => bundleSource.compiledIdentity).thenReturn(_identity);
    client = DesktopAnalyticsClient();
  });

  group("events logged before the service starts", () {
    test("wait for it, and are delivered in order", () async {
      final api = _FakeEventApi();
      final service = serviceFor(api: api);

      await logAnswered();
      await logRejected();
      await pumpEventQueue();
      expect(api.attempts, isEmpty);

      service.start();
      await pumpEventQueue();

      expect(api.attempts.map((attempt) => attempt.request.name), [
        "session_question_answered",
        "session_question_rejected",
      ]);
    });

    test("stay ahead of an event logged while they are being delivered", () async {
      final api = _FakeEventApi();
      final service = serviceFor(api: api);

      await logAnswered();
      service.start();
      await logRejected();
      await pumpEventQueue();
      await logAborted();
      await pumpEventQueue();

      expect(api.attempts.map((attempt) => attempt.request.name), [
        "session_question_answered",
        "session_question_rejected",
        "session_abort_succeeded",
      ]);
    });

    test("desktop startup calls the service's start() once, ahead of the analytics service's", () {
      final code = File("lib/main.dart")
          .readAsStringSync()
          .replaceAll(RegExp(r"/\*.*?\*/", dotAll: true), "")
          .replaceAll(RegExp("//.*"), "");
      const delivery = "getIt<DesktopProductAnalyticsDeliveryService>().start()";
      const analytics = "productAnalyticsService.start()";

      expect(delivery.allMatches(code), hasLength(1));
      expect(analytics.allMatches(code), hasLength(1));
      expect(code.indexOf(delivery), lessThan(code.indexOf(analytics)));
    });
  });

  group("once the service has started", () {
    test("an event carries the account current when it was logged", () async {
      final api = _FakeEventApi();
      serviceFor(api: api).start();

      final logged = logAnswered();
      when(() => authSession.currentState).thenReturn(const AuthState.authenticated(user: _userB));
      await logged;
      await pumpEventQueue();

      expect(api.attempts.single.userId, _userA.id);
    });

    test("the user key stays behind", () async {
      final api = _FakeEventApi();
      serviceFor(api: api).start();

      await logAnswered();
      await pumpEventQueue();

      expect(jsonEncode(api.attempts.single.request.toJson()), isNot(contains(_userKey)));
    });
  });

  group("not blocking the caller", () {
    test("returns before a POST that never completes", () async {
      final api = _FakeEventApi();
      api.never = Completer<ApiResponse<bool>>().future;
      serviceFor(api: api).start();

      await logAnswered();
      await pumpEventQueue();

      expect(api.attempts, hasLength(1));
    });

    testWidgets("a send that throws never reaches the caller", (tester) async {
      final api = _FakeEventApi();
      api.thrown = StateError("the connection went away");
      serviceFor(api: api).start();

      await logAnswered();
      await tester.pump(const Duration(hours: 1));

      // Each retry threw too. An error that escaped would fail this test.
      expect(api.attempts, hasLength(3));
    });
  });

  group("teardown", () {
    test("disposing finishes when nothing ever listened, and later events are ignored", () async {
      await logAnswered();

      await client.dispose().timeout(const Duration(seconds: 1));

      await expectLater(logAnswered(), completes);
    });

    test("cancelling the service and then closing the client delivers nothing further", () async {
      final api = _FakeEventApi();
      final service = serviceFor(api: api);
      service.start();

      await service.dispose();
      await expectLater(logAnswered(), completes);
      await client.dispose().timeout(const Duration(seconds: 1));
      await expectLater(logRejected(), completes);
      await pumpEventQueue();

      expect(api.attempts, isEmpty);
    });
  });

  test("the installation and activation calls stream nothing", () async {
    final received = <ProductAnalyticsEnvelope>[];
    client.events.listen(received.add);

    await client.logInstallationEvent(
      event: const InstallationAnalyticsEvent.loginAttemptStarted(provider: AnalyticsLoginProvider.github),
    );
    await client.activateAfterInteractiveAuthentication();
    await pumpEventQueue();

    expect(received, isEmpty);
  });
}
