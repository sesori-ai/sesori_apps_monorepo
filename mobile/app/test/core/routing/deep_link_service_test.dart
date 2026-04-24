import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/routing/deep_link_service.dart";

import "../../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  group("DeepLinkService", () {
    late MockOAuthCallbackDispatcher mockOAuthCallbackDispatcher;
    late MockDeepLinkSource mockDeepLinkSource;
    late StreamController<Uri> controller;
    late DeepLinkService service;

    setUp(() {
      mockOAuthCallbackDispatcher = MockOAuthCallbackDispatcher();
      mockDeepLinkSource = MockDeepLinkSource();
      controller = StreamController<Uri>.broadcast();

      when(() => mockDeepLinkSource.linkStream).thenAnswer((_) => controller.stream);
      when(() => mockOAuthCallbackDispatcher.handleOAuthCallback(any())).thenAnswer((_) async => const AppRoute.projects());

      service = DeepLinkService(mockOAuthCallbackDispatcher, mockDeepLinkSource);
    });

    tearDown(() async {
      service.dispose();
      await controller.close();
    });

    test("init subscribes to link stream", () async {
      // given
      var listenCount = 0;
      await controller.close();
      controller = StreamController<Uri>.broadcast(onListen: () => listenCount++);
      when(() => mockDeepLinkSource.linkStream).thenAnswer((_) => controller.stream);
      service = DeepLinkService(mockOAuthCallbackDispatcher, mockDeepLinkSource);

      // when
      service.init();
      await Future<void>.delayed(Duration.zero);

      // then
      expect(listenCount, 1);
    });

    test("handles valid OAuth callback URI", () async {
      // given
      service.init();
      const uri = "com.sesori.app://auth/callback?code=abc&state=xyz";

      // when
      controller.add(Uri.parse(uri));
      await Future<void>.delayed(Duration.zero);

      // then
      verify(() => mockOAuthCallbackDispatcher.handleOAuthCallback(Uri.parse(uri))).called(1);
    });

    test("ignores URI with wrong scheme", () async {
      // given
      service.init();

      // when
      controller.add(Uri.parse("https://example.com/auth/callback"));
      await Future<void>.delayed(Duration.zero);

      // then
      verifyNever(() => mockOAuthCallbackDispatcher.handleOAuthCallback(any()));
    });

    test("ignores URI with wrong path", () async {
      // given
      service.init();

      // when
      controller.add(Uri.parse("com.sesori.app://auth/other/path?code=abc&state=xyz"));
      await Future<void>.delayed(Duration.zero);

      // then
      verifyNever(() => mockOAuthCallbackDispatcher.handleOAuthCallback(any()));
    });

    test("ignores URI with wrong host", () async {
      // given
      service.init();

      // when
      controller.add(Uri.parse("com.sesori.app://notauth/callback?code=abc&state=xyz"));
      await Future<void>.delayed(Duration.zero);

      // then
      verifyNever(() => mockOAuthCallbackDispatcher.handleOAuthCallback(any()));
    });

    test("double init is no-op", () async {
      // given
      var listenCount = 0;
      await controller.close();
      controller = StreamController<Uri>.broadcast(onListen: () => listenCount++);
      when(() => mockDeepLinkSource.linkStream).thenAnswer((_) => controller.stream);
      service = DeepLinkService(mockOAuthCallbackDispatcher, mockDeepLinkSource);

      // when
      service.init();
      service.init();
      await Future<void>.delayed(Duration.zero);

      // then
      expect(listenCount, 1);
    });

    test("dispose cancels subscription and allows re-init", () async {
      // given
      var listenCount = 0;
      await controller.close();
      controller = StreamController<Uri>.broadcast(onListen: () => listenCount++);
      when(() => mockDeepLinkSource.linkStream).thenAnswer((_) => controller.stream);
      service = DeepLinkService(mockOAuthCallbackDispatcher, mockDeepLinkSource);

      // when
      service.init();
      await Future<void>.delayed(Duration.zero);
      service.dispose();
      await Future<void>.delayed(Duration.zero);
      service.init();
      await Future<void>.delayed(Duration.zero);

      // then
      expect(listenCount, 2);
    });

    test("concurrent callback processing is guarded", () async {
      // given
      final completer = Completer<AppRoute?>();
      when(() => mockOAuthCallbackDispatcher.handleOAuthCallback(any())).thenAnswer((_) => completer.future);
      service.init();

      // when
      controller.add(Uri.parse("com.sesori.app://auth/callback?code=first&state=one"));
      controller.add(Uri.parse("com.sesori.app://auth/callback?code=second&state=two"));
      await Future<void>.delayed(Duration.zero);

      // then
      verify(() => mockOAuthCallbackDispatcher.handleOAuthCallback(any())).called(1);

      completer.complete(const AppRoute.projects());
      await Future<void>.delayed(Duration.zero);
    });
  });
}
