import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_motion_tuning/sesori_motion_tuning.dart";

import "feedback_motion_spec.dart";
import "feedback_motion_tuning_playbook.dart";

void main() {
  var nativeRequests = 0;
  const nativeReview = MethodChannel("com.sesori.app/feedback_preview");

  setUp(() {
    nativeRequests = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(nativeReview, (
      call,
    ) async {
      nativeRequests++;
      return null;
    });
  });
  tearDown(
    () =>
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(nativeReview, null),
  );

  testWidgets("long star timing stays aligned with step advancement", (tester) async {
    await _open(tester: tester);
    _replay(
      tester: tester,
      scene: FeedbackMotionScene.step,
      values: const MotionSnapshot()
          .withInput(parameter: feedbackSheetOpenDuration, input: 0)
          .withInput(parameter: feedbackStarDuration, input: 1000),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text("What should we improve?"), findsNothing);
    expect(find.byKey(const ValueKey("rating-3")), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 416));
    await tester.pumpAndSettle();
    expect(find.text("What should we improve?"), findsOneWidget);
    expect(nativeRequests, 0);
    expect(tester.takeException(), isNull);
  });

  for (final scene in FeedbackMotionScene.values) {
    testWidgets("${scene.name} replays safely with instant sheet transitions", (tester) async {
      await _open(tester: tester);
      _replay(
        tester: tester,
        scene: scene,
        values: const MotionSnapshot()
            .withInput(parameter: feedbackSheetOpenDuration, input: 0)
            .withInput(parameter: feedbackSheetCloseDuration, input: 0),
      );
      await tester.pump();
      await tester.pump();
      // Pump the simulated delays in order; each interval permits a rendered frame.
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      switch (scene) {
        case FeedbackMotionScene.sheetOpen || FeedbackMotionScene.stars:
          expect(find.byKey(const ValueKey("rating-3")), findsOneWidget);
        case FeedbackMotionScene.sheetClose:
          expect(find.byKey(const ValueKey("rating-3")), findsNothing);
        case FeedbackMotionScene.step || FeedbackMotionScene.issues:
          expect(find.text("What should we improve?"), findsOneWidget);
        case FeedbackMotionScene.composer || FeedbackMotionScene.voice:
          expect(find.byKey(const ValueKey("feedback-text")), findsOneWidget);
        case FeedbackMotionScene.notice || FeedbackMotionScene.flow:
          expect(find.text("Feedback sent. Thank you!"), findsOneWidget);
      }
      expect(nativeRequests, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("restarting a sequence disposes its pending actions", (tester) async {
    await _open(tester: tester);
    final instantSheet = const MotionSnapshot().withInput(parameter: feedbackSheetOpenDuration, input: 0);
    _replay(tester: tester, scene: FeedbackMotionScene.flow, values: instantSheet);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    _replay(tester: tester, scene: FeedbackMotionScene.stars, values: instantSheet);
    await tester.pump();
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey("rating-3")), findsOneWidget);
    expect(find.text("Feedback sent. Thank you!"), findsNothing);
    expect(nativeRequests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets("manual high rating also skips native requests in tuning mode", (tester) async {
    await _open(tester: tester);
    await tester.tap(find.byKey(const ValueKey("rating-5")));
    await tester.pumpAndSettle();
    expect(find.text("Native rating skipped during motion preview."), findsOneWidget);
    expect(nativeRequests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets("reduced motion keeps the selected star stationary during replay", (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _open(tester: tester);
    _replay(
      tester: tester,
      scene: FeedbackMotionScene.stars,
      values: const MotionSnapshot().withInput(parameter: feedbackStarPeak, input: 1.4),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final transform = tester.widget<Transform>(
      find.descendant(
        of: find.byKey(const ValueKey("rating-3")),
        matching: find.byType(Transform),
      ),
    );
    expect(transform.transform.entry(0, 0), 1);
    expect(nativeRequests, 0);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _open({required WidgetTester tester}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(const FeedbackMotionTuningPlaybook());
  await tester.pumpAndSettle();
}

void _replay({required WidgetTester tester, required FeedbackMotionScene scene, required MotionSnapshot values}) {
  tester
      .widget<MotionTuningHost>(find.byType(MotionTuningHost))
      .onReplay(
        target: feedbackMotionTargets.singleWhere((target) => target.id == scene.name),
        values: values,
      );
}
