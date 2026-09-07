import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

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
      "$rating stars stays private through category-only submission",
      (tester) async {
        await _launch(tester: tester);
        await _open(tester: tester);
        await _rate(tester: tester, rating: rating);

        expect(find.text("What should we improve?"), findsOneWidget);
        expect(nativeRequests, isEmpty);
        expect(find.byKey(const ValueKey("feedback-text")), findsNothing);
        expect(_control(label: "Send feedback"), findsNothing);

        await _tap(tester: tester, finder: find.text("Hard to navigate"));
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
      expect(_control(label: "Send feedback"), findsNothing);
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
    "hold-to-talk produces an editable sample without submitting it",
    (tester) async {
      await _launch(tester: tester);
      await _open(tester: tester);
      await _rate(tester: tester, rating: 2);
      final voice = find.byKey(const ValueKey("feedback-voice"));
      await tester.ensureVisible(voice);
      final hold = await tester.startGesture(tester.getCenter(voice));
      await tester.pump(const Duration(milliseconds: 600));
      await hold.up();
      await tester.pump();
      expect(find.text("Transcribing…"), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 950));
      await tester.pumpAndSettle();

      expect(_textField(tester: tester).controller?.text, contains("The design is clean"));
      expect(find.text("What should we improve?"), findsOneWidget);
      expect(find.text("Feedback sent. Thank you!"), findsNothing);
      expect(nativeRequests, isEmpty);

      await _tap(tester: tester, finder: find.byKey(const ValueKey("feedback-text")));
      expect(_textField(tester: tester).readOnly, isFalse);
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
