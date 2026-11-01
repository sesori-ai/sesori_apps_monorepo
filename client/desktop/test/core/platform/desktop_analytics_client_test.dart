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
const _delivered = ProductAnalyticsEventDeliveryResult.delivered();

class _MockAuthSession() extends Mock implements AuthSession;

class _MockAppInfoSource() extends Mock implements DesktopAppInfoSource;

class _FakeEventApi({required final ProductAnalyticsEventDeliveryResult result}) implements ProductAnalyticsEventApi {
  final List<({String userId, ProductAnalyticsEventRequest request})> attempts = [];
  Future<ProductAnalyticsEventDeliveryResult>? never;

  @override
  Future<ProductAnalyticsEventDeliveryResult> send({
    required String userId,
    required ProductAnalyticsEventRequest request,
  }) async {
    attempts.add((userId: userId, request: request));
    final pending = never;
    if (pending != null) return await pending;
    return result;
  }
}

void main() {
  late _MockAuthSession authSession;
  late _MockAppInfoSource appInfo;
  late DesktopAnalyticsClient client;

  DesktopProductAnalyticsDeliveryService serviceFor({required _FakeEventApi api}) =>
      DesktopProductAnalyticsDeliveryService(
        eventSource: client,
        repository: ProductAnalyticsEventRepository(api: api),
        authSession: authSession,
        appInfoSource: appInfo,
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
    appInfo = _MockAppInfoSource();
    when(() => appInfo.platform).thenReturn(DesktopBundleOs.macos);
    when(() => appInfo.readVersion()).thenAnswer((_) async => "1.11.0");
    client = DesktopAnalyticsClient();
  });

  group("events logged before the service starts", () {
    test("wait for it, and are delivered in order", () async {
      final api = _FakeEventApi(result: _delivered);
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
      final api = _FakeEventApi(result: _delivered);
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

    test("desktop startup starts the service before anything can log an event", () {
      final main = File("lib/main.dart").readAsStringSync();
      final delivery = main.indexOf("getIt<DesktopProductAnalyticsDeliveryService>().start()");
      final analytics = main.indexOf("productAnalyticsService.start()");

      expect(delivery, isNot(-1));
      expect(analytics, isNot(-1));
      expect(delivery, lessThan(analytics));
    });
  });

  group("once the service has started", () {
    test("an event carries the account current when it was logged", () async {
      final api = _FakeEventApi(result: _delivered);
      serviceFor(api: api).start();

      final logged = logAnswered();
      when(() => authSession.currentState).thenReturn(const AuthState.authenticated(user: _userB));
      await logged;
      await pumpEventQueue();

      expect(api.attempts.single.userId, _userA.id);
    });

    test("the user key stays behind", () async {
      final api = _FakeEventApi(result: _delivered);
      serviceFor(api: api).start();

      await logAnswered();
      await pumpEventQueue();

      expect(jsonEncode(api.attempts.single.request.toJson()), isNot(contains(_userKey)));
    });
  });

  group("not blocking the caller", () {
    test("returns before a POST that never completes", () async {
      final api = _FakeEventApi(result: _delivered);
      api.never = Completer<ProductAnalyticsEventDeliveryResult>().future;
      serviceFor(api: api).start();

      await logAnswered();
      await pumpEventQueue();

      expect(api.attempts, hasLength(1));
    });

    test("returns before an app version read that never completes", () async {
      when(() => appInfo.readVersion()).thenAnswer((_) => Completer<String>().future);
      final api = _FakeEventApi(result: _delivered);
      serviceFor(api: api).start();

      await logAnswered();

      expect(api.attempts, isEmpty);
    });

    test("a failed send never reaches the caller", () async {
      final api = _FakeEventApi(
        result: const ProductAnalyticsEventDeliveryResult.permanentFailure(description: "HTTP 400", cause: null),
      );
      serviceFor(api: api).start();

      await expectLater(logAnswered(), completes);
      await pumpEventQueue();

      expect(api.attempts, hasLength(1));
    });
  });

  group("teardown", () {
    test("disposing finishes when nothing ever listened, and later events are ignored", () async {
      await logAnswered();

      await client.dispose().timeout(const Duration(seconds: 1));

      await expectLater(logAnswered(), completes);
    });

    test("disposing in DI order, service first, delivers nothing further", () async {
      final api = _FakeEventApi(result: _delivered);
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
