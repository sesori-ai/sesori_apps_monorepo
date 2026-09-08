import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "feedback_flow_playbook.dart";

void main() {
  testWidgets(
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    "composer buttons can paint their full pressed scale without rectangular clipping",
    (tester) async {
      await _openPrivate(tester: tester);
      await tester.tap(find.text("Hard to navigate"));
      await tester.pumpAndSettle();

      for (final label in ["Use keyboard", "Send feedback"]) {
        final button = _control(label: label);
        final hold = await tester.startGesture(tester.getCenter(button));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        final enlarged = tester
            .widgetList<Transform>(
              find.descendant(of: button, matching: find.byType(Transform)),
            )
            .where((transform) => transform.transform.entry(0, 0) > 1);
        expect(enlarged, isNotEmpty);
        final painted = tester.renderObject<RenderTransform>(find.byWidget(enlarged.first)).child!;
        final paintedBounds = MatrixUtils.transformRect(painted.getTransformTo(null), painted.paintBounds);
        RenderObject? ancestor = painted.parent;
        while (ancestor != null) {
          if (ancestor is RenderClipRect && ancestor.clipBehavior != Clip.none) {
            final clipBounds = MatrixUtils.transformRect(ancestor.getTransformTo(null), ancestor.paintBounds);
            expect(clipBounds.contains(paintedBounds.topLeft), isTrue, reason: "$label is clipped at its top/left");
            expect(
              clipBounds.contains(paintedBounds.bottomRight),
              isTrue,
              reason: "$label is clipped at its bottom/right",
            );
          }
          ancestor = ancestor.parent;
        }
        await hold.cancel();
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    "rating content fades into feedback while the same sheet resizes",
    (tester) async {
      await _launch(tester: tester);
      final sheet = tester.element(find.byType(BottomSheet));
      await tester.tap(find.byKey(const ValueKey("rating-2")));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 470));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text("How’s Sesori working for you?"), findsOneWidget);
      expect(find.text("What should we improve?"), findsOneWidget);
      expect(tester.element(find.byType(BottomSheet)), same(sheet));
      expect(find.byKey(const ValueKey("rating-2")).hitTestable(), findsNothing);
      final fades = tester.widgetList<FadeTransition>(
        find.ancestor(of: find.text("What should we improve?"), matching: find.byType(FadeTransition)),
      );
      expect(fades.any((fade) => fade.opacity.value > 0 && fade.opacity.value < 1), isTrue);
      await tester.pumpAndSettle();
      expect(find.text("How’s Sesori working for you?"), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    "chip press responds before release while composer actions stay in place",
    (tester) async {
      await _openPrivate(tester: tester);
      final chip = find.text("Hard to navigate");
      final keyboard = _control(label: "Use keyboard");
      final initialX = tester.getCenter(keyboard).dx;
      final hold = await tester.startGesture(tester.getCenter(chip));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final press = tester.widget<AnimatedScale>(find.ancestor(of: chip, matching: find.byType(AnimatedScale)));
      expect(press.scale, 0.97);
      expect(_control(label: "Send feedback"), findsOneWidget);
      await hold.up();
      await tester.pump();
      expect(tester.getCenter(keyboard).dx, closeTo(initialX, 0.01));
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.getCenter(keyboard).dx, closeTo(initialX, 0.01));
      await tester.pumpAndSettle();
      expect(tester.getCenter(keyboard).dx, closeTo(initialX, 0.01));

      // Repeated issue toggles must keep the same single Send action.
      await tester.tap(chip);
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(_control(label: "Send feedback"), findsOneWidget);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(_control(label: "Send feedback"), findsOneWidget);
      expect(tester.getCenter(keyboard).dx, closeTo(initialX, 0.01));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    "typing and longer drafts keep the editor and sheet stationary",
    (tester) async {
      await _openPrivate(tester: tester);
      await tester.tap(_control(label: "Use keyboard"));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey("feedback-text"));
      final initialField = tester.getRect(field);
      final initialSheet = tester.getRect(find.byType(BottomSheet));
      for (final text in ["a", "First line\nSecond line\nThird line\nFourth line\nFifth line", ""]) {
        await tester.enterText(field, text);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.getRect(field), initialField);
        expect(tester.getRect(find.byType(BottomSheet)), initialSheet);
        expect(tester.widget<TextField>(field).controller?.text, text);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    "voice acknowledges touch before recording and releases into transcription",
    (tester) async {
      await _openPrivate(tester: tester);
      final voice = find.byKey(const ValueKey("feedback-voice"));
      final hold = await tester.startGesture(tester.getCenter(voice));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<AnimatedScale>(find.descendant(of: voice, matching: find.byType(AnimatedScale))).scale,
        0.97,
      );
      expect(find.byType(PregoVoiceWaveform), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PregoVoiceWaveform), findsOneWidget);
      await hold.up();
      await tester.pump();
      expect(find.text("Transcribing…"), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 950));
      await tester.pumpAndSettle();
      expect(find.byType(PregoVoiceWaveform), findsNothing);
      expect(find.byKey(const ValueKey("feedback-text")), findsOneWidget);
      expect(_control(label: "Use keyboard"), findsNothing);
      expect(_control(label: "Send feedback"), findsOneWidget);
      final field = find.byKey(const ValueKey("feedback-text"));
      final transcript = tester.widget<TextField>(field).controller!.text;
      final more = await tester.startGesture(tester.getCenter(voice));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(PregoVoiceWaveform), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, transcript);
      await more.up();
      await tester.pump();
      expect(find.text("Transcribing…"), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, transcript);
      await tester.pump(const Duration(milliseconds: 950));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, "$transcript $transcript");
      expect(_control(label: "Use keyboard"), findsNothing);
      expect(_control(label: "Send feedback"), findsOneWidget);
      expect(find.text("Feedback sent. Thank you!"), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final features in [
    const FakeAccessibilityFeatures(disableAnimations: true),
    const FakeAccessibilityFeatures(reduceMotion: true),
  ]) {
    testWidgets(
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      "$features suppresses sheet travel and press scaling without losing feedback",
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue = features;
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        await _launch(tester: tester);
        final route = ModalRoute.of(tester.element(find.byType(BottomSheet)));
        expect(route?.transitionDuration, Duration.zero);
        expect(route?.reverseTransitionDuration, Duration.zero);
        await _rate(tester: tester);
        final chip = find.text("Hard to navigate");
        final hold = await tester.startGesture(tester.getCenter(chip));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.widget<AnimatedScale>(find.ancestor(of: chip, matching: find.byType(AnimatedScale))).scale, 1);
        await hold.up();
        await tester.pumpAndSettle();
        expect(tester.widget<Semantics>(_control(label: "Hard to navigate")).properties.checked, isTrue);
        expect(_control(label: "Send feedback"), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    "enabling iOS Reduce Motion keeps the current draft and issue selection",
    (tester) async {
      await _openPrivate(tester: tester);
      await tester.tap(find.text("Connection drops"));
      await tester.pumpAndSettle();
      await tester.tap(_control(label: "Use keyboard"));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey("feedback-text"));
      await tester.enterText(field, "Keep my draft");
      await tester.pump();
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller?.text, "Keep my draft");
      expect(tester.widget<Semantics>(_control(label: "Connection drops")).properties.checked, isTrue);
      final route = ModalRoute.of(tester.element(find.byType(BottomSheet)));
      expect(route?.reverseTransitionDuration, Duration.zero);
      await tester.tap(find.text("Cancel"));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    "microphone denial requests native settings and keeps selected issues",
    (tester) async {
      const channel = MethodChannel("com.sesori.app/feedback_preview");
      final requests = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        requests.add(call.method);
        return false;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
      await _openScenario(tester: tester, scenario: FeedbackPreviewScenario.microphoneDenied);
      await tester.tap(find.text("Connection drops"));
      await tester.pumpAndSettle();
      await tester.tap(_control(label: "Hold to talk to give feedback"));
      await tester.pumpAndSettle();
      expect(requests, ["requestMicrophoneAccess"]);
      expect(find.textContaining("Microphone access is off"), findsNothing);
      await tester.tap(_control(label: "Use keyboard"));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey("feedback-text")), findsOneWidget);
      expect(tester.widget<Semantics>(_control(label: "Connection drops")).properties.checked, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    "transcription failure shows an auto-dismissed top toast and accepts a fresh recording",
    (tester) async {
      await _openScenario(tester: tester, scenario: FeedbackPreviewScenario.transcriptionRetry);
      await tester.tap(_control(label: "Hold to talk to give feedback"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      await tester.tap(_control(label: "Finish recording"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 950));
      await tester.pumpAndSettle();
      final toast = find.byType(PregoPopupAlertsNotifications);
      expect(find.text("Couldn’t transcribe that. Please try again."), findsOneWidget);
      expect(tester.getBottomRight(toast).dy, lessThan(tester.getTopLeft(find.byType(BottomSheet)).dy));
      expect(find.text("Retry transcription"), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(toast, findsNothing);
      await tester.tap(_control(label: "Hold to talk to give feedback"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(_control(label: "Finish recording"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 950));
      await tester.pumpAndSettle();
      expect(find.text("Couldn’t transcribe that. Please try again."), findsNothing);
      expect(find.byKey(const ValueKey("feedback-text")), findsOneWidget);
      expect(find.text("Feedback sent. Thank you!"), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _launch({required WidgetTester tester}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(const FeedbackFlowPlaybook(openOnLaunch: true));
  await tester.pumpAndSettle();
}

Future<void> _openPrivate({required WidgetTester tester}) async {
  await _launch(tester: tester);
  await _rate(tester: tester);
}

Future<void> _rate({required WidgetTester tester}) async {
  await tester.tap(find.byKey(const ValueKey("rating-2")));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 490));
  await tester.pumpAndSettle();
}

Future<void> _openScenario({required WidgetTester tester, required FeedbackPreviewScenario scenario}) async {
  await _launch(tester: tester);
  await tester.tap(find.text("Not now"));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<FeedbackPreviewScenario>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(scenario.label).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text("Open feedback"));
  await tester.pumpAndSettle();
  await _rate(tester: tester);
}

Finder _control({required String label}) =>
    find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == label);
