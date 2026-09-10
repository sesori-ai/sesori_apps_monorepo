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

  testWidgets("celebration replay uses its edited duration and stays inside the preview", (tester) async {
    await _open(tester: tester);
    _replay(
      tester: tester,
      scene: FeedbackMotionScene.celebration,
      values: const MotionSnapshot()
          .withInput(parameter: feedbackSheetOpenDuration, input: 0)
          .withInput(parameter: feedbackCelebrationDuration, input: 4000),
    );
    await tester.pump();
    await tester.pump();
    final began = tester.binding.clock.now();
    await tester.pumpAndSettle();
    expect(tester.binding.clock.now().difference(began), greaterThanOrEqualTo(const Duration(milliseconds: 3900)));
    expect(find.byKey(const ValueKey("feedback-love")), findsOneWidget);
    expect(find.text("What should we improve?"), findsNothing);
    expect(nativeRequests, 0);
    expect(tester.takeException(), isNull);
  });

  for (final scene in [FeedbackMotionScene.step, FeedbackMotionScene.flow]) {
    testWidgets("${scene.name} enters private feedback without waiting for celebration", (tester) async {
      await _open(tester: tester);
      _replay(
        tester: tester,
        scene: scene,
        values: const MotionSnapshot()
            .withInput(parameter: feedbackSheetOpenDuration, input: 0)
            .withInput(parameter: feedbackCelebrationDuration, input: 4000),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text("What should we improve?"), findsOneWidget);
      expect(find.byKey(const ValueKey("feedback-love")), findsNothing);
      expect(nativeRequests, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  }

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
      var sawResultToast = false;
      for (var frame = 0; frame < 40; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
        sawResultToast = sawResultToast || find.text("Feedback sent. Thank you!").evaluate().isNotEmpty;
      }
      switch (scene) {
        case FeedbackMotionScene.sheetOpen || FeedbackMotionScene.celebration:
          expect(find.byKey(const ValueKey("feedback-love")), findsOneWidget);
        case FeedbackMotionScene.sheetClose:
          expect(find.byKey(const ValueKey("feedback-love")), findsNothing);
        case FeedbackMotionScene.step || FeedbackMotionScene.issues:
          expect(find.text("What should we improve?"), findsOneWidget);
        case FeedbackMotionScene.composer || FeedbackMotionScene.voice:
          expect(find.byKey(const ValueKey("feedback-text")), findsOneWidget);
        case FeedbackMotionScene.notice || FeedbackMotionScene.flow:
          expect(sawResultToast, isTrue);
      }
      expect(nativeRequests, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("notice replay uses the shared top toast and its automatic dismissal", (tester) async {
    await _open(tester: tester);
    _replay(
      tester: tester,
      scene: FeedbackMotionScene.notice,
      values: const MotionSnapshot()
          .withInput(parameter: feedbackSheetOpenDuration, input: 0)
          .withInput(parameter: feedbackSheetCloseDuration, input: 0),
    );
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    final toast = find.byKey(const ValueKey("prego_popup_alert"));
    expect(toast, findsOneWidget);
    expect(tester.getTopLeft(toast).dy, lessThan(844 / 2));
    expect(find.text("Feedback sent. Thank you!"), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(toast, findsNothing);
    expect(nativeRequests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets("restarting a sequence disposes its pending actions", (tester) async {
    await _open(tester: tester);
    final instantSheet = const MotionSnapshot().withInput(parameter: feedbackSheetOpenDuration, input: 0);
    _replay(tester: tester, scene: FeedbackMotionScene.flow, values: instantSheet);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    _replay(tester: tester, scene: FeedbackMotionScene.celebration, values: instantSheet);
    await tester.pump();
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey("feedback-love")), findsOneWidget);
    expect(find.text("Feedback sent. Thank you!"), findsNothing);
    expect(nativeRequests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets("manual Yes also skips native requests in tuning mode", (tester) async {
    await _open(tester: tester);
    await tester.tap(find.byKey(const ValueKey("feedback-love")));
    await tester.pumpAndSettle();
    expect(find.text("Native rating skipped during motion preview."), findsOneWidget);
    expect(nativeRequests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets("reduced motion completes celebration replay without a timed animation", (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await _open(tester: tester);
    _replay(
      tester: tester,
      scene: FeedbackMotionScene.celebration,
      values: const MotionSnapshot()
          .withInput(parameter: feedbackSheetOpenDuration, input: 0)
          .withInput(parameter: feedbackCelebrationDuration, input: 4000),
    );
    final began = tester.binding.clock.now();
    await tester.pumpAndSettle();
    expect(tester.binding.clock.now().difference(began), lessThan(const Duration(milliseconds: 500)));
    expect(find.byKey(const ValueKey("feedback-love")), findsOneWidget);
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
