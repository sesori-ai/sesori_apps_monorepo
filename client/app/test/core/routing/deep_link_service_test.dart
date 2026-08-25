import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/routing/deep_link_service.dart";

import "../../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  group("DeepLinkService", () {
    late MockDeepLinkSource deepLinkSource;
    late MockAuthSession authSession;
    late StreamController<Uri> links;
    late BehaviorSubject<AuthState> authStates;
    late _RecordingRouteDispatcher routeDispatcher;
    late DeepLinkService service;

    setUp(() {
      deepLinkSource = MockDeepLinkSource();
      authSession = MockAuthSession();
      links = StreamController<Uri>.broadcast();
      authStates = BehaviorSubject<AuthState>.seeded(_authenticatedState());
      routeDispatcher = _RecordingRouteDispatcher();

      when(() => deepLinkSource.linkStream).thenAnswer((_) => links.stream);
      when(() => authSession.authStateStream).thenAnswer((_) => authStates.stream);
      when(() => authSession.currentState).thenAnswer((_) => authStates.value);
      service = DeepLinkService(deepLinkSource, authSession, routeDispatcher);
    });

    tearDown(() async {
      service.dispose();
      await links.close();
      await authStates.close();
    });

    test("init subscribes once", () async {
      var listenCount = 0;
      await links.close();
      links = StreamController<Uri>.broadcast(onListen: () => listenCount++);
      when(() => deepLinkSource.linkStream).thenAnswer((_) => links.stream);

      service.init();
      service.init();
      await Future<void>.delayed(Duration.zero);

      expect(listenCount, 1);
    });

    test("keeps OAuth callbacks as a no-op", () async {
      service.init();

      links.add(Uri.parse("com.sesori.app://auth/callback?code=abc&state=xyz"));
      await Future<void>.delayed(Duration.zero);

      expect(routeDispatcher.replacedStacks, isEmpty);
    });

    test("parses encoded Device Canvas identifiers without double decoding", () {
      final route = DeepLinkService.parseDeviceCanvasSessionUri(
        Uri.parse(
          "com.sesori.app:///sessions/session%3Fone"
          "?bridgeId=bridge-1&readOnly=false",
        ),
      );

      expect(route, isNotNull);
      expect(route!.sessionId, "session?one");
      expect(route.bridgeId, "bridge-1");
      expect(route.readOnly, isFalse);
    });

    test("rejects malformed or non-Device Canvas links", () {
      final links = [
        "https://example.com/sessions/s?bridgeId=b&readOnly=false",
        "com.sesori.app:/sessions/s?bridgeId=b&readOnly=false",
        "com.sesori.app://sessions/s?bridgeId=b&readOnly=false",
        "com.sesori.app:///sessions/s?readOnly=false",
        "com.sesori.app:///sessions/s?bridgeId=&readOnly=false",
        "com.sesori.app:///sessions/s?bridgeId=b&readOnly=true",
        "com.sesori.app:///sessions/s?bridgeId=b&readOnly=false&extra=1",
        "com.sesori.app:///sessions/s/extra?bridgeId=b&readOnly=false",
        "com.sesori.app:///sessions/s?bridgeId=b&readOnly=false#fragment",
        "com.sesori.app:///projects/%2FUsers%2Fdev%2FPrivate/sessions/s?bridgeId=b&readOnly=false",
      ];

      for (final link in links) {
        expect(DeepLinkService.parseDeviceCanvasSessionUri(Uri.parse(link)), isNull, reason: link);
      }
    });

    test("dispatches a projectless bridge-scoped session stack", () async {
      service.init();

      links.add(
        Uri.parse(
          "com.sesori.app:///sessions/session-1"
          "?bridgeId=bridge-1&readOnly=false",
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(routeDispatcher.replacedStacks, hasLength(1));
      final paths = routeDispatcher.replacedStacks.single.paths;
      expect(paths, hasLength(2));
      expect(paths.first, const AppRoute.projects().buildPath());
      final detail = Uri.parse(paths.last);
      expect(detail.path, "/sessions/session-1");
      expect(detail.queryParameters[bridgeIdQueryParam], "bridge-1");
      expect(detail.queryParameters["readOnly"], "false");
      expect(detail.toString(), isNot(contains("project")));
    });

    test("queues only the latest link until authentication completes", () async {
      authStates.add(const AuthState.unauthenticated());
      service.init();
      links.add(
        Uri.parse("com.sesori.app:///sessions/s1?bridgeId=b1&readOnly=false"),
      );
      links.add(
        Uri.parse("com.sesori.app:///sessions/s2?bridgeId=b2&readOnly=false"),
      );
      await Future<void>.delayed(Duration.zero);
      expect(routeDispatcher.replacedStacks, isEmpty);

      authStates.add(_authenticatedState());
      await Future<void>.delayed(Duration.zero);

      expect(routeDispatcher.replacedStacks, hasLength(1));
      final detail = Uri.parse(routeDispatcher.replacedStacks.single.paths.last);
      expect(detail.path, "/sessions/s2");
      expect(detail.queryParameters[bridgeIdQueryParam], "b2");
    });

    test("dispose allows re-init", () async {
      var listenCount = 0;
      await links.close();
      links = StreamController<Uri>.broadcast(onListen: () => listenCount++);
      when(() => deepLinkSource.linkStream).thenAnswer((_) => links.stream);

      service.init();
      await Future<void>.delayed(Duration.zero);
      service.dispose();
      await Future<void>.delayed(Duration.zero);
      service.init();
      await Future<void>.delayed(Duration.zero);

      expect(listenCount, 2);
    });
  });
}

AuthState _authenticatedState() => const AuthState.authenticated(
  user: AuthUser(
    id: "user-1",
    provider: AuthProvider.email,
    providerUserId: "user@example.com",
    providerUsername: "user@example.com",
  ),
);

class _RecordingRouteDispatcher() implements RouteDispatcher {
  final List<RouteStack> replacedStacks = [];

  @override
  void replaceStack({required RouteStack stack}) => replacedStacks.add(stack);
}
