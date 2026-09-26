import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

import "feedback_flow_playbook.dart";
import "feedback_rating_motion.dart";

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const nativeReview = MethodChannel("com.sesori.app/feedback_preview");
  final requests = <MethodCall>[];
  final requestTimes = <DateTime>[];
  final sheetsAtRequest = <bool>[];

  setUp(() {
    requests.clear();
    requestTimes.clear();
    sheetsAtRequest.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(nativeReview, (call) async {
      requests.add(call);
      requestTimes.add(binding.clock.now());
      sheetsAtRequest.add(find.byType(BottomSheet, skipOffstage: false).evaluate().isNotEmpty);
      return null;
    });
  });
  tearDown(() => binding.defaultBinaryMessenger.setMockMethodCallHandler(nativeReview, null));

  testWidgets("Yes preserves the opening timing and closes once after the 1.5-second celebration", (tester) async {
    await _open(tester: tester);
    final heroAnimation = tester.widget<FeedbackRatingHero>(find.byType(FeedbackRatingHero)).animation;
    expect(tester.widget<FeedbackLoveButton>(find.byType(FeedbackLoveButton)).animation, same(heroAnimation));
    final tappedAt = tester.binding.clock.now();
    await tester.tap(find.byKey(const ValueKey("feedback-love")));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(heroAnimation.value, closeTo(0.25, 0.0001), reason: "The first 1.2s retain the authored Figma timing.");
    expect(tester.widget<FeedbackLoveButton>(find.byType(FeedbackLoveButton)).animation, same(heroAnimation));
    expect(tester.widget<TextButton>(find.byKey(const ValueKey("feedback-love"))).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey("feedback-love")), warnIfMissed: false);
    await tester.tap(find.byKey(const ValueKey("feedback-improve")), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(heroAnimation.value, closeTo(0.6, 0.0001));
    await tester.pump(const Duration(milliseconds: 299));
    expect(requests, isEmpty);
    expect(find.text("Are you enjoying Sesori?"), findsOneWidget);
    expect(find.text("What should we improve?"), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    // Use normal frame intervals so route disposal does not inherit an artificial 100ms frame delay.
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(requests, isEmpty, reason: "The native prompt must wait for the closing sheet animation.");
    expect(find.byType(BottomSheet, skipOffstage: false), findsOneWidget);
    await tester.pumpAndSettle(const Duration(milliseconds: 16));

    expect(requests, hasLength(1));
    expect(
      requestTimes.single.difference(tappedAt),
      allOf(
        greaterThanOrEqualTo(const Duration(milliseconds: 1600)),
        lessThanOrEqualTo(const Duration(milliseconds: 1800)),
      ),
    );
    expect(requests.single.method, "requestReview");
    expect(requests.single.arguments, isNull);
    expect(sheetsAtRequest, [false]);
    expect(find.byType(BottomSheet, skipOffstage: false), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(requests, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets("closing during the celebration cancels the pending native request", (tester) async {
    await _open(tester: tester);
    await tester.tap(find.byKey(const ValueKey("feedback-love")));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey("feedback-close")));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    expect(requests, isEmpty);
    expect(find.byType(BottomSheet, skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final (label, features) in [
    ("disableAnimations", const FakeAccessibilityFeatures(disableAnimations: true)),
    ("reduceMotion", const FakeAccessibilityFeatures(reduceMotion: true)),
  ]) {
    testWidgets("$label requests review after closing without the 1.5-second celebration delay", (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = features;
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await _open(tester: tester);
      final began = tester.binding.clock.now();
      await tester.tap(find.byKey(const ValueKey("feedback-love")));
      await tester.pumpAndSettle();

      expect(tester.binding.clock.now().difference(began), lessThan(const Duration(milliseconds: 500)));
      expect(requests, hasLength(1));
      expect(sheetsAtRequest, [false]);
      expect(find.byType(BottomSheet, skipOffstage: false), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets("enabling $label during celebration completes promptly without a duplicate review", (tester) async {
      await _open(tester: tester);
      await tester.tap(find.byKey(const ValueKey("feedback-love")));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(requests, isEmpty);

      final changed = tester.binding.clock.now();
      tester.platformDispatcher.accessibilityFeaturesTestValue = features;
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpAndSettle();
      expect(tester.binding.clock.now().difference(changed), lessThan(const Duration(milliseconds: 500)));
      expect(requests, hasLength(1));
      expect(sheetsAtRequest, [false]);
      await tester.pump(const Duration(seconds: 3));
      expect(requests, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _open({required WidgetTester tester}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(const FeedbackFlowPlaybook(openOnLaunch: true));
  await tester.pumpAndSettle();
}
