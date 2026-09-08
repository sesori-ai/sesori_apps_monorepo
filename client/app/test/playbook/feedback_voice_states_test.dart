import "dart:async";

import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "feedback_flow_playbook.dart";

void main() {
  const channel = MethodChannel("com.sesori.app/feedback_preview");
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <MethodCall>[];
  late Completer<bool> permission;

  setUp(() {
    requests.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) {
      requests.add(call);
      return permission.future;
    });
  });
  tearDown(() => binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      variant: TargetPlatformVariant.only(platform),
      "already-authorized access records on the first hold",
      (tester) async {
        permission = Completer<bool>()..complete(true);
        await _open(tester: tester, permissionScenario: true);
        final hold = await _hold(tester: tester);
        expect(requests, hasLength(1));
        expect(find.byType(PregoVoiceWaveform), findsOneWidget);
        await hold.up();
        await _finishTranscription(tester: tester);
        expect(_draft(tester: tester), contains("The design is clean"));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      variant: TargetPlatformVariant.only(platform),
      "a native prompt round trip requires a fresh hold even before release",
      (tester) async {
        permission = Completer<bool>();
        await _open(tester: tester, permissionScenario: true);
        final hold = await _hold(tester: tester);
        // The native handler returns false after any UI round trip, even a
        // successful grant. A later check can authorize a fresh gesture.
        permission.complete(false);
        await tester.pumpAndSettle();
        expect(find.byType(PregoVoiceWaveform), findsNothing);
        await hold.up();
        permission = Completer<bool>()..complete(true);
        final freshHold = await _hold(tester: tester);
        expect(find.byType(PregoVoiceWaveform), findsOneWidget);
        expect(requests, hasLength(2));
        await freshHold.up();
        await _finishTranscription(tester: tester);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      variant: TargetPlatformVariant.only(platform),
      "late authorization after release waits for a fresh gesture",
      (tester) async {
        permission = Completer<bool>();
        await _open(tester: tester, permissionScenario: true);
        final originalHold = await _hold(tester: tester);
        expect(requests.single.method, "requestMicrophoneAccess");
        expect(requests.single.arguments, isNull);
        expect(find.text("Microphone access…"), findsOneWidget);
        expect(find.byType(PregoVoiceWaveform), findsNothing);
        await originalHold.up();
        permission.complete(true);
        await tester.pumpAndSettle();
        expect(find.text("Hold to talk to give feedback"), findsOneWidget);
        expect(find.byType(PregoVoiceWaveform), findsNothing);
        expect(find.text("Transcribing…"), findsNothing);

        final freshHold = await _hold(tester: tester);
        expect(find.byType(PregoVoiceWaveform), findsOneWidget);
        expect(requests, hasLength(2));
        await freshHold.up();
        await _finishTranscription(tester: tester);
        expect(_draft(tester: tester), contains("The design is clean"));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      variant: TargetPlatformVariant.only(platform),
      "permission denial preserves draft and issues and permits another native request",
      (tester) async {
        permission = Completer<bool>();
        await _open(tester: tester, permissionScenario: true);
        await _prepareDraft(tester: tester);
        final hold = await _hold(tester: tester);
        await hold.up();
        permission.complete(false);
        await tester.pumpAndSettle();
        expect(_draft(tester: tester), _existingDraft);
        _expectSelectedIssue(tester: tester);
        expect(find.byType(PregoVoiceWaveform), findsNothing);
        expect(find.text("Hold to talk more"), findsOneWidget);

        permission = Completer<bool>();
        final retry = await _hold(tester: tester);
        expect(requests.map((call) => call.method), ["requestMicrophoneAccess", "requestMicrophoneAccess"]);
        await retry.up();
        permission.complete(false);
        await tester.pumpAndSettle();
        expect(_draft(tester: tester), _existingDraft);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      variant: TargetPlatformVariant.only(platform),
      "native microphone failure shows a top toast and restores the idle composer",
      (tester) async {
        permission = Completer<bool>();
        await _open(tester: tester, permissionScenario: true);
        final hold = await _hold(tester: tester);
        await hold.up();
        permission.completeError(PlatformException(code: "settings_unavailable"));
        await tester.pumpAndSettle();
        expect(find.text("Couldn’t open microphone settings. Please try again."), findsOneWidget);
        expect(
          tester.getBottomRight(find.byType(PregoPopupAlertsNotifications)).dy,
          lessThan(tester.getTopLeft(find.byType(BottomSheet)).dy),
        );
        expect(find.text("Hold to talk to give feedback"), findsOneWidget);
        expect(find.byType(PregoVoiceWaveform), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      variant: TargetPlatformVariant.only(platform),
      "closing feedback while native permission is pending ignores its late grant",
      (tester) async {
        permission = Completer<bool>();
        await _open(tester: tester, permissionScenario: true);
        final hold = await _hold(tester: tester);
        await hold.up();
        await _tap(tester: tester, finder: find.text("Cancel"));
        expect(find.byType(BottomSheet), findsNothing);
        permission.complete(true);
        await tester.pumpAndSettle();
        expect(find.byType(PregoVoiceWaveform), findsNothing);
        expect(find.text("Transcribing…"), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets("dragging to Cancel flattens the waveform and discards only the recording", (tester) async {
    await _open(tester: tester);
    await _prepareDraft(tester: tester);
    final hold = await _hold(tester: tester);
    await hold.moveTo(tester.getCenter(_control(label: "Cancel recording")));
    await tester.pump();
    expect(find.text("Release to cancel"), findsOneWidget);
    expect(tester.widget<PregoVoiceWaveform>(find.byType(PregoVoiceWaveform)).flattenProgress?.value, 1);
    await hold.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 950));
    expect(find.byType(PregoVoiceWaveform), findsNothing);
    expect(find.text("Transcribing…"), findsNothing);
    expect(_draft(tester: tester), _existingDraft);
    _expectSelectedIssue(tester: tester);
    expect(requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets("dragging back out of Cancel restores recording and release appends transcription", (tester) async {
    await _open(tester: tester);
    await _prepareDraft(tester: tester);
    final hold = await _hold(tester: tester);
    await hold.moveTo(tester.getCenter(_control(label: "Cancel recording")));
    await tester.pump();
    expect(find.text("Release to cancel"), findsOneWidget);
    await hold.moveTo(tester.getTopRight(find.byKey(const ValueKey("feedback-voice"))) + const Offset(-8, 22));
    await tester.pump();
    expect(find.text("Release to transcribe"), findsOneWidget);
    expect(tester.widget<PregoVoiceWaveform>(find.byType(PregoVoiceWaveform)).flattenProgress?.value, 0);
    await hold.up();
    await _finishTranscription(tester: tester);
    expect(_draft(tester: tester), startsWith("$_existingDraft "));
    expect(_draft(tester: tester), contains("The design is clean"));
    _expectSelectedIssue(tester: tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets("the direct Cancel recording button restores the existing draft", (tester) async {
    await _open(tester: tester);
    await _prepareDraft(tester: tester);
    await tester.tap(find.byKey(const ValueKey("feedback-voice")));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PregoVoiceWaveform), findsOneWidget);
    await tester.tap(_control(label: "Cancel recording"));
    await tester.pumpAndSettle();
    expect(find.byType(PregoVoiceWaveform), findsNothing);
    expect(_draft(tester: tester), _existingDraft);
    _expectSelectedIssue(tester: tester);
    expect(tester.takeException(), isNull);
  });
}

const _existingDraft = "Please keep my existing feedback.";

Future<void> _open({required WidgetTester tester, bool permissionScenario = false}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(const FeedbackFlowPlaybook(openOnLaunch: false));
  await tester.pumpAndSettle();
  if (permissionScenario) {
    await _tap(tester: tester, finder: find.byType(DropdownButtonFormField<FeedbackPreviewScenario>));
    await _tap(tester: tester, finder: find.text(FeedbackPreviewScenario.microphoneDenied.label).last);
  }
  await _tap(
    tester: tester,
    finder: find.ancestor(of: find.text("Open feedback"), matching: find.byType(PregoButtonsSolid)),
  );
  await _tap(tester: tester, finder: find.byKey(const ValueKey("rating-2")));
}

Future<void> _prepareDraft({required WidgetTester tester}) async {
  await _tap(tester: tester, finder: find.text("Connection drops"));
  await _tap(
    tester: tester,
    finder: _control(label: "Use keyboard"),
  );
  await tester.enterText(find.byKey(const ValueKey("feedback-text")), _existingDraft);
  await _tap(
    tester: tester,
    finder: _control(label: "Use voice input"),
  );
}

Future<TestGesture> _hold({required WidgetTester tester}) async {
  final voice = find.byKey(const ValueKey("feedback-voice"));
  await tester.ensureVisible(voice);
  final hold = await tester.startGesture(tester.getCenter(voice));
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 400));
  return hold;
}

Future<void> _finishTranscription({required WidgetTester tester}) async {
  await tester.pump();
  expect(find.text("Transcribing…"), findsOneWidget);
  await tester.pump(const Duration(milliseconds: 950));
  await tester.pumpAndSettle();
}

Future<void> _tap({required WidgetTester tester, required Finder finder}) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

String? _draft({required WidgetTester tester}) =>
    tester.widget<TextField>(find.byKey(const ValueKey("feedback-text"))).controller?.text;

void _expectSelectedIssue({required WidgetTester tester}) =>
    expect(tester.widget<Semantics>(_control(label: "Connection drops")).properties.checked, isTrue);

Finder _control({required String label}) =>
    find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == label);
