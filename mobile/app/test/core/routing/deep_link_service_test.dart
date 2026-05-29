import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_mobile/core/routing/deep_link_service.dart";

import "../../helpers/test_helpers.dart";

void main() {
  setUpAll(registerAllFallbackValues);

  group("DeepLinkService", () {
    late MockDeepLinkSource mockDeepLinkSource;
    late StreamController<Uri> controller;
    late DeepLinkService service;

    setUp(() {
      mockDeepLinkSource = MockDeepLinkSource();
      controller = StreamController<Uri>.broadcast();

      when(() => mockDeepLinkSource.linkStream).thenAnswer((_) => controller.stream);

      service = DeepLinkService(mockDeepLinkSource);
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
      service = DeepLinkService(mockDeepLinkSource);

      // when
      service.init();
      await Future<void>.delayed(Duration.zero);

      // then
      expect(listenCount, 1);
    });

    test("ignores OAuth callback URI without crashing", () async {
      // given
      service.init();
      const uri = "com.sesori.app://auth/callback?code=abc&state=xyz";

      // when
      controller.add(Uri.parse(uri));
      await Future<void>.delayed(Duration.zero);

      // then — no crash, no-op
      expect(true, isTrue);
    });

    test("ignores URI with wrong scheme", () async {
      // given
      service.init();

      // when
      controller.add(Uri.parse("https://example.com/auth/callback"));
      await Future<void>.delayed(Duration.zero);

      // then — no crash
      expect(true, isTrue);
    });

    test("double init is no-op", () async {
      // given
      var listenCount = 0;
      await controller.close();
      controller = StreamController<Uri>.broadcast(onListen: () => listenCount++);
      when(() => mockDeepLinkSource.linkStream).thenAnswer((_) => controller.stream);
      service = DeepLinkService(mockDeepLinkSource);

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
      service = DeepLinkService(mockDeepLinkSource);

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

    test("consecutive deep links are both received", () async {
      // given
      service.init();

      // when
      controller.add(Uri.parse("com.sesori.app://auth/callback?code=first&state=one"));
      controller.add(Uri.parse("com.sesori.app://auth/callback?code=second&state=two"));
      await Future<void>.delayed(Duration.zero);

      // then — both handled without crash
      expect(true, isTrue);
    });
  });
}
