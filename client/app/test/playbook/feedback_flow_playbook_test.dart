import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

import "feedback_flow_playbook.dart";

void main() {
  for (final rating in [1, 2, 3]) {
    testWidgets("$rating stars stays private through category-only submission", (tester) async {
      await _launch(tester: tester);
      await _open(tester: tester);
      await _rate(tester: tester, rating: rating);

      expect(find.text("What should we improve?"), findsOneWidget);
      expect(find.text("Preview · no store request"), findsNothing);
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
      expect(find.text("Preview · no store request"), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final rating in [4, 5]) {
    testWidgets("$rating stars opens a labeled store-review simulation", (tester) async {
      await _launch(tester: tester);
      await _open(tester: tester);
      await _rate(tester: tester, rating: rating);

      expect(find.text("Preview · no store request"), findsOneWidget);
      expect(find.text("Enjoying Sesori?"), findsOneWidget);
      expect(find.text("What should we improve?"), findsNothing);

      await _tap(tester: tester, finder: find.byKey(ValueKey("native-$rating")));
      await _tap(tester: tester, finder: find.text("Done"));

      expect(find.text("Preview · no store request"), findsNothing);
      expect(find.text("Feedback sent. Thank you!"), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("Not now and Cancel dismiss, and reopening starts with a fresh rating", (tester) async {
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
    expect(tester.takeException(), isNull);
  });

  testWidgets("failed submission preserves typed feedback and Retry completes privately", (tester) async {
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
    expect(find.text("Preview · no store request"), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("hold-to-talk produces an editable sample without submitting it", (tester) async {
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
    expect(find.text("Preview · no store request"), findsNothing);

    await _tap(tester: tester, finder: find.byKey(const ValueKey("feedback-text")));
    expect(_textField(tester: tester).readOnly, isFalse);
    await tester.enterText(find.byKey(const ValueKey("feedback-text")), "My edited feedback.");
    expect(_textField(tester: tester).controller?.text, "My edited feedback.");
    expect(find.text("Feedback sent. Thank you!"), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("small-screen private feedback remains usable with large text and a keyboard", (tester) async {
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
    expect(tester.takeException(), isNull);
  });
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
