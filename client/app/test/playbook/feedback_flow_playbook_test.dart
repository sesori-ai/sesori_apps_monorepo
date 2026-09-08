import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "feedback_flow_playbook.dart";

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const nativeReviewChannel = MethodChannel("com.sesori.app/feedback_preview");
  final nativeRequests = <MethodCall>[];
  final sheetsPresentDuringNativeRequest = <bool>[];
  Exception? nativeFailure;

  setUp(() {
    nativeRequests.clear();
    sheetsPresentDuringNativeRequest.clear();
    nativeFailure = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(nativeReviewChannel, (call) async {
      nativeRequests.add(call);
      sheetsPresentDuringNativeRequest.add(find.byType(BottomSheet, skipOffstage: false).evaluate().isNotEmpty);
      if (nativeFailure case final failure?) throw failure;
      return null;
    });
  });

  tearDown(() => binding.defaultBinaryMessenger.setMockMethodCallHandler(nativeReviewChannel, null));

  for (final rating in [1, 2, 3]) {
    testWidgets(
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      "$rating stars stays private through rating-only submission",
      (tester) async {
        await _launch(tester: tester);
        await _open(tester: tester);
        await _rate(tester: tester, rating: rating);

        expect(find.text("What should we improve?"), findsOneWidget);
        expect(nativeRequests, isEmpty);
        expect(find.byKey(const ValueKey("feedback-text")), findsNothing);
        expect(_control(label: "Send feedback"), findsOneWidget);
        expect(tester.widget<Semantics>(_control(label: "Send feedback")).properties.enabled, isTrue);

        await _tap(
          tester: tester,
          finder: _control(label: "Send feedback"),
        );
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pumpAndSettle();

        expect(find.text("Feedback sent. Thank you!"), findsOneWidget);
        expect(find.text("What should we improve?"), findsNothing);
        expect(nativeRequests, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    "category-only feedback can still be submitted",
    (tester) async {
      await _launch(tester: tester);
      await _open(tester: tester);
      await _rate(tester: tester, rating: 2);
      await _tap(tester: tester, finder: find.text("Hard to navigate"));
      await _tap(
        tester: tester,
        finder: _control(label: "Send feedback"),
      );
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      expect(find.text("Feedback sent. Thank you!"), findsOneWidget);
      expect(nativeRequests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final rating in [4, 5]) {
    testWidgets(
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      "$rating stars requests native review once after the feedback sheet is removed",
      (tester) async {
        await _launch(tester: tester);
        await _open(tester: tester);
        expect(find.byType(BottomSheet, skipOffstage: false), findsOneWidget);
        await _rate(tester: tester, rating: rating);

        expect(nativeRequests, hasLength(1));
        expect(nativeRequests.single.method, "requestReview");
        expect(nativeRequests.single.arguments, isNull);
        expect(sheetsPresentDuringNativeRequest, [false]);
        expect(find.byType(BottomSheet, skipOffstage: false), findsNothing);
        expect(find.byType(Dialog), findsNothing);
        expect(find.text("What should we improve?"), findsNothing);
        expect(find.text("Feedback sent. Thank you!"), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    "feedback confirmation clears the top bar and disappears automatically",
    (tester) async {
      await _launch(tester: tester);
      tester.view.padding = const FakeViewPadding(top: 47);
      addTearDown(tester.view.resetPadding);
      await tester.pumpAndSettle();
      await _open(tester: tester);
      await _rate(tester: tester, rating: 2);
      await _tap(tester: tester, finder: find.text("Hard to navigate"));
      await _tap(
        tester: tester,
        finder: _control(label: "Send feedback"),
      );
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      final toast = find.byType(PregoPopupAlertsNotifications);
      expect(find.text("Feedback sent. Thank you!"), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.getTopLeft(toast).dy, 47 + PregoTopNavigation.barHeight + PregoSpacing.xl);
      await tester.pump(const Duration(seconds: 2));
      expect(toast, findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(toast, findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(nativeRequests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final failure in <({Exception error, String notice})>[
    (error: MissingPluginException(), notice: "Native rating is available in the iOS debug preview."),
    (
      error: PlatformException(code: "native_review_unavailable"),
      notice: "Couldn’t open native rating. Please try again.",
    ),
  ]) {
    testWidgets(
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      "native ${failure.error.runtimeType} displays an explicit notice without a fake dialog",
      (
        tester,
      ) async {
        nativeFailure = failure.error;
        await _launch(tester: tester);
        await _open(tester: tester);
        await _rate(tester: tester, rating: 5);

        expect(nativeRequests, hasLength(1));
        expect(nativeRequests.single.method, "requestReview");
        expect(sheetsPresentDuringNativeRequest, [false]);
        expect(find.text(failure.notice), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
        expect(find.text("Feedback sent. Thank you!"), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    "Not now and Cancel dismiss, and reopening starts with a fresh rating",
    (tester) async {
      await _launch(tester: tester);
      await _open(tester: tester);
      await _tap(tester: tester, finder: find.text("Not now"));
      expect(find.text("How’s Sesori working for you?"), findsNothing);

      await _open(tester: tester);
      await _rate(tester: tester, rating: 2);
      await _tap(tester: tester, finder: find.text("Connection drops"));
      await _tap(tester: tester, finder: find.text("Cancel"));
      expect(find.text("What should we improve?"), findsNothing);

      await _open(tester: tester);
      expect(find.text("How’s Sesori working for you?"), findsOneWidget);
      await _rate(tester: tester, rating: 1);
      expect(_control(label: "Send feedback"), findsOneWidget);
      expect(find.text("Feedback sent. Thank you!"), findsNothing);
      expect(nativeRequests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    "failed submission preserves typed feedback and Retry completes privately",
    (tester) async {
      const draft = "The task list is difficult to navigate.";
      await _launch(tester: tester);
      await _scenario(tester: tester, scenario: FeedbackPreviewScenario.submissionRetry);
      await _open(tester: tester);
      await _rate(tester: tester, rating: 3);
      await _tap(
        tester: tester,
        finder: _control(label: "Use keyboard"),
      );
      await tester.enterText(find.byKey(const ValueKey("feedback-text")), draft);
      await _tap(
        tester: tester,
        finder: _control(label: "Send feedback"),
      );
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      expect(find.text("Couldn’t send feedback. Your draft is still here."), findsOneWidget);
      expect(_textField(tester: tester).controller?.text, draft);
      expect(find.text("Feedback sent. Thank you!"), findsNothing);

      await _tap(tester: tester, finder: find.text("Retry"));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      expect(find.text("Feedback sent. Thank you!"), findsOneWidget);
      expect(nativeRequests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    "voice-first transcription replaces keyboard with Send inside the Figma voice pill",
    (tester) async {
      await _launch(tester: tester, size: const Size(402, 874));
      await _open(tester: tester);
      await _rate(tester: tester, rating: 2);
      final voice = find.byKey(const ValueKey("feedback-voice"));
      final pill = find.byKey(const ValueKey("feedback-voice-pill"));
      final composer = find.byKey(const ValueKey("feedback-composer"));
      expect(find.byKey(const ValueKey("feedback-text")), findsNothing);
      expect(_control(label: "Use keyboard"), findsOneWidget);
      expect(_control(label: "Send feedback"), findsOneWidget);
      expect(tester.getSize(pill), const Size(370, 56));
      await tester.ensureVisible(voice);
      final hold = await tester.startGesture(tester.getCenter(voice));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.widget<Semantics>(_control(label: "Send feedback")).properties.enabled, isFalse);
      await hold.up();
      await tester.pump();
      expect(find.text("Transcribing…"), findsOneWidget);
      expect(_control(label: "Send feedback"), findsOneWidget);
      expect(tester.widget<Semantics>(_control(label: "Send feedback")).properties.enabled, isFalse);
      await tester.pump(const Duration(milliseconds: 950));
      await tester.pumpAndSettle();

      expect(_textField(tester: tester).controller?.text, contains("The design is clean"));
      expect(_control(label: "Use keyboard"), findsNothing);
      expect(_control(label: "Send feedback"), findsOneWidget);
      expect(find.text("Hold to talk more"), findsOneWidget);
      expect(_textField(tester: tester).readOnly, isTrue);
      final composerRect = tester.getRect(composer);
      final pillRect = tester.getRect(pill);
      expect(pillRect.size, const Size(358, 56));
      expect(pillRect.left - composerRect.left, 6);
      expect(composerRect.right - pillRect.right, 6);
      expect(composerRect.bottom - pillRect.bottom, 6);
      final editorRect = tester.getRect(find.byType(EditableText));
      expect(editorRect.left - composerRect.left, 10);
      expect(editorRect.top - composerRect.top, 14);
      expect(composerRect.right - editorRect.right, 37);
      final decoration = tester.widget<TweenAnimationBuilder<Decoration>>(composer).tween.end! as BoxDecoration;
      expect(
        decoration.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(20), bottom: Radius.circular(34)),
      );
      expect(find.text("What should we improve?"), findsOneWidget);
      expect(find.text("Feedback sent. Thank you!"), findsNothing);
      expect(nativeRequests, isEmpty);

      await _tap(tester: tester, finder: find.byKey(const ValueKey("feedback-text")));
      expect(_textField(tester: tester).readOnly, isFalse);
      expect(_control(label: "Use voice input"), findsOneWidget);
      expect(_control(label: "Send feedback"), findsOneWidget);
      expect(pill, findsNothing);
      final focusedDecoration = tester.widget<TweenAnimationBuilder<Decoration>>(composer).tween.end! as BoxDecoration;
      expect(
        focusedDecoration.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(20), bottom: Radius.circular(26)),
      );
      expect(focusedDecoration.boxShadow?.map((shadow) => shadow.spreadRadius), [4, 2]);
      await tester.enterText(find.byKey(const ValueKey("feedback-text")), "My edited feedback.");
      expect(_textField(tester: tester).controller?.text, "My edited feedback.");
      expect(find.text("Feedback sent. Thank you!"), findsNothing);
      expect(nativeRequests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    "small-screen private feedback remains usable with large text and a keyboard",
    (tester) async {
      await _launch(tester: tester, size: const Size(320, 568));
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      await _open(tester: tester);
      expect(tester.takeException(), isNull);
      await _rate(tester: tester, rating: 3);
      await _tap(
        tester: tester,
        finder: _control(label: "Use keyboard"),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey("feedback-text")), "Please make the navigation clearer.");
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await _tap(
        tester: tester,
        finder: _control(label: "Send feedback"),
      );
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      expect(find.text("Feedback sent. Thank you!"), findsOneWidget);
      expect(nativeRequests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _launch({required WidgetTester tester, Size size = const Size(390, 844)}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(const FeedbackFlowPlaybook(openOnLaunch: false));
  await tester.pumpAndSettle();
}

Future<void> _open({required WidgetTester tester}) async {
  final button = find.text("Open feedback");
  if (button.evaluate().isEmpty) {
    await tester.scrollUntilVisible(button, 200, scrollable: find.byType(Scrollable).first);
  }
  await _tap(tester: tester, finder: button);
}

Future<void> _rate({required WidgetTester tester, required int rating}) async {
  await _tap(tester: tester, finder: find.byKey(ValueKey("rating-$rating")));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}

Future<void> _scenario({required WidgetTester tester, required FeedbackPreviewScenario scenario}) async {
  await _tap(tester: tester, finder: find.byType(DropdownButtonFormField<FeedbackPreviewScenario>));
  await _tap(tester: tester, finder: find.text(scenario.label).last);
}

Future<void> _tap({required WidgetTester tester, required Finder finder}) async {
  await tester.pump();
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _control({required String label}) =>
    find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == label);

TextField _textField({required WidgetTester tester}) =>
    tester.widget<TextField>(find.byKey(const ValueKey("feedback-text")));
