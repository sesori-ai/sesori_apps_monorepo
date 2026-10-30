import "dart:async";
import "dart:ui" show SemanticsAction;

import "package:bloc_test/bloc_test.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockVoiceInputCubit() extends MockCubit<VoiceInputState> implements VoiceInputCubit;

/// What one composer did, for the endings to assert on.
class _Composer() {
  final List<({String text, String? command})> sent = [];
  final List<AnalyticsVoiceFinish> finishes = [];
  int commandsCleared = 0;
}

void main() {
  late StreamController<VoiceInputState> voiceStates;
  late _MockVoiceInputCubit voiceCubit;

  setUp(() {
    voiceStates = StreamController<VoiceInputState>();
    voiceCubit = _MockVoiceInputCubit();
    whenListen(voiceCubit, voiceStates.stream, initialState: const VoiceInputState.idle());
    when(() => voiceCubit.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(voiceCubit.startRecording).thenAnswer((_) async {
      voiceStates.add(const VoiceInputState.recording());
      await Future<void>.delayed(Duration.zero);
    });
    when(() => voiceCubit.stopAndTranscribe(limitReached: false)).thenAnswer((_) async {
      voiceStates.add(const VoiceInputState.transcribing(limitReached: false));
    });
    when(voiceCubit.cancel).thenAnswer((_) async {
      voiceStates.add(const VoiceInputState.idle());
    });
    when(voiceCubit.retry).thenAnswer((_) async {});
    addTearDown(voiceStates.close);
    addTearDown(voiceCubit.close);
  });

  Future<void> emitVoice({required WidgetTester tester, required VoiceInputState state}) async {
    voiceStates.add(state);
    await tester.pump();
    await tester.pump();
  }

  Future<void> complete({
    required WidgetTester tester,
    required String transcript,
    required VoiceDictationOutcome outcome,
  }) async {
    await emitVoice(
      tester: tester,
      state: VoiceInputState.completed(transcript: transcript, outcome: outcome),
    );
    await emitVoice(tester: tester, state: const VoiceInputState.idle());
    // Past the transcribing presentation's bounded transitions.
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Holds past the 200 ms minimum, with the morph settled; the waveform never
  /// settles, so frames are pumped explicitly.
  Future<TestGesture> hold({required WidgetTester tester, required ChatInputMode mode}) async {
    final gesture = await tester.startGesture(tester.getCenter(_holdTarget(mode: mode)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return gesture;
  }

  Future<void> slideOntoPencil({required WidgetTester tester, required TestGesture gesture}) async {
    await gesture.moveTo(tester.getCenter(find.byType(PregoVoiceTarget)));
    await tester.pump();
  }

  Offset abovePill({required WidgetTester tester, required double by}) {
    final pencil = tester.getTopLeft(find.byType(PregoVoiceTarget));
    // The pill's top edge is one small spacing above the pencil.
    return Offset(tester.getCenter(find.byType(PregoVoiceWaveform)).dx, pencil.dy - PregoSpacing.sm - by);
  }

  for (final mode in ChatInputMode.values) {
    group("touch, ${mode.name}", () {
      testWidgets("releasing sends the words at once and reports sent", (tester) async {
        final composer = await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: mode);

        final gesture = await hold(tester: tester, mode: mode);
        expect(find.text("Release to send · slide up to cancel"), findsOneWidget);
        expect(find.byIcon(TablerRegular.pencil), findsOneWidget);
        expect(
          tester.getCenter(find.byType(PregoVoiceTarget)).dx,
          lessThan(tester.getCenter(find.byType(PregoVoiceWaveform)).dx),
          reason: "The pencil sits to the far left in both input modes.",
        );

        await gesture.up();
        await tester.pump();
        verify(() => voiceCubit.stopAndTranscribe(limitReached: false)).called(1);
        expect(composer.sent, isEmpty, reason: "Nothing leaves until the words exist.");

        await complete(tester: tester, transcript: "spoken words", outcome: VoiceDictationOutcome.finished);
        expect(composer.sent, [(text: "spoken words", command: null)]);
        expect(composer.finishes, [AnalyticsVoiceFinish.sent]);
        expect(find.text("spoken words"), findsNothing, reason: "The box empties as the message leaves.");
      });

      testWidgets("releasing on the pencil puts the words in the box and reports edited", (tester) async {
        final composer = await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: mode);

        final gesture = await hold(tester: tester, mode: mode);
        await slideOntoPencil(tester: tester, gesture: gesture);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text("Release to edit"), findsOneWidget);

        await gesture.up();
        await tester.pump();
        await complete(tester: tester, transcript: "spoken words", outcome: VoiceDictationOutcome.finished);

        expect(composer.sent, isEmpty);
        expect(composer.finishes, [AnalyticsVoiceFinish.edited]);
        expect(find.text("spoken words"), findsOneWidget);
      });

      testWidgets("sliding up out of the pill cancels and keeps the box", (tester) async {
        final composer = await _pumpComposer(
          tester: tester,
          voiceCubit: voiceCubit,
          mode: mode,
          initialText: "Typed first",
        );

        final gesture = await hold(tester: tester, mode: mode);
        await gesture.moveTo(abovePill(tester: tester, by: 64));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text("Release to cancel"), findsOneWidget);

        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        verify(voiceCubit.cancel).called(1);
        verifyNever(() => voiceCubit.stopAndTranscribe(limitReached: false));
        expect(find.text("Typed first"), findsOneWidget);
        expect(composer.sent, isEmpty);
        expect(composer.finishes, isEmpty);
      });

      testWidgets("sliding up and back, then releasing, still sends", (tester) async {
        final composer = await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: mode);

        final gesture = await hold(tester: tester, mode: mode);
        final holdPoint = tester.getCenter(find.byType(PregoVoiceWaveform));
        await gesture.moveTo(abovePill(tester: tester, by: 64));
        await tester.pump();
        await gesture.moveTo(holdPoint);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text("Release to send · slide up to cancel"), findsOneWidget);

        await gesture.up();
        await tester.pump();
        verifyNever(voiceCubit.cancel);
        await complete(tester: tester, transcript: "spoken words", outcome: VoiceDictationOutcome.finished);

        expect(composer.sent, [(text: "spoken words", command: null)]);
      });

      testWidgets("the wash and hint follow the finger without moving the composer", (tester) async {
        await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: mode);
        final composerRect = tester.getRect(find.byType(PromptInput));

        double washOpacity() => tester
            .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .singleWhere((fade) => fade.duration == Duration.zero)
            .opacity;

        final gesture = await hold(tester: tester, mode: mode);
        expect(washOpacity(), 0);

        await gesture.moveTo(abovePill(tester: tester, by: 32));
        await tester.pump();
        expect(washOpacity(), 0.5);
        expect(find.text("Release to send · slide up to cancel"), findsOneWidget);
        expect(tester.getRect(find.byType(PromptInput)), composerRect);

        // Below the arm line a retreat scrubs back with no tolerance.
        await gesture.moveTo(abovePill(tester: tester, by: 16));
        await tester.pump();
        expect(washOpacity(), 0.25);

        await gesture.moveTo(abovePill(tester: tester, by: 64));
        await tester.pump();
        expect(washOpacity(), 1);
        expect(tester.getRect(find.byType(PromptInput)), composerRect);

        await gesture.up();
        await tester.pump();
      });

      testWidgets("a hold under 200 ms sends nothing", (tester) async {
        final composer = await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: mode);

        final gesture = await tester.startGesture(tester.getCenter(_holdTarget(mode: mode)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        verify(voiceCubit.cancel).called(1);
        verifyNever(() => voiceCubit.stopAndTranscribe(limitReached: false));
        expect(composer.sent, isEmpty);
        expect(composer.finishes, isEmpty);
      });

      testWidgets("an empty transcript sends nothing, not even what the box holds", (tester) async {
        final composer = await _pumpComposer(
          tester: tester,
          voiceCubit: voiceCubit,
          mode: mode,
          initialText: "Typed first",
        );

        final gesture = await hold(tester: tester, mode: mode);
        await gesture.up();
        await tester.pump();
        await complete(tester: tester, transcript: "  ", outcome: VoiceDictationOutcome.finished);

        expect(composer.sent, isEmpty);
        expect(composer.finishes, isEmpty);
        expect(find.text("Typed first"), findsOneWidget);
      });

      testWidgets("words join what the box held and leave together", (tester) async {
        final composer = await _pumpComposer(
          tester: tester,
          voiceCubit: voiceCubit,
          mode: mode,
          initialText: "Typed first",
        );

        final gesture = await hold(tester: tester, mode: mode);
        await gesture.up();
        await tester.pump();
        await complete(tester: tester, transcript: "and spoken", outcome: VoiceDictationOutcome.finished);

        expect(composer.sent, [(text: "Typed first and spoken", command: null)]);
      });

      testWidgets("reaching the limit lands in the box with one notice", (tester) async {
        final composer = await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: mode);

        final gesture = await hold(tester: tester, mode: mode);
        await emitVoice(tester: tester, state: const VoiceInputState.transcribing(limitReached: true));
        expect(find.text("Recording limit reached (15 minutes)"), findsOneWidget);

        await complete(tester: tester, transcript: "cut off words", outcome: VoiceDictationOutcome.limitReached);
        await gesture.up();
        await tester.pump();

        expect(composer.sent, isEmpty);
        expect(composer.finishes, [AnalyticsVoiceFinish.cutOff]);
        expect(find.text("cut off words"), findsOneWidget);
        expect(find.text("Recording limit reached (15 minutes)"), findsOneWidget);
      });

      testWidgets("a release that hits the limit before the stop still lands in the box", (tester) async {
        final composer = await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: mode);

        final gesture = await hold(tester: tester, mode: mode);
        await gesture.up();
        await tester.pump();
        await complete(tester: tester, transcript: "cut off words", outcome: VoiceDictationOutcome.limitReached);

        expect(composer.sent, isEmpty);
        expect(composer.finishes, [AnalyticsVoiceFinish.cutOff]);
        expect(find.text("cut off words"), findsOneWidget);
      });

      testWidgets("a completion with the finger still down lands in the box", (tester) async {
        final composer = await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: mode);

        final gesture = await hold(tester: tester, mode: mode);
        await complete(tester: tester, transcript: "spoken words", outcome: VoiceDictationOutcome.finished);
        await gesture.up();
        await tester.pump();

        expect(composer.sent, isEmpty);
        expect(composer.finishes, [AnalyticsVoiceFinish.edited]);
        expect(find.text("spoken words"), findsOneWidget);
      });

      testWidgets("words stay in the box when the composer refuses to send", (tester) async {
        final composer = await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: mode, canSend: false);

        final gesture = await hold(tester: tester, mode: mode);
        await gesture.up();
        await tester.pump();
        await complete(tester: tester, transcript: "spoken words", outcome: VoiceDictationOutcome.finished);

        expect(composer.sent, isEmpty);
        expect(composer.finishes, [AnalyticsVoiceFinish.edited]);
        expect(find.text("spoken words"), findsOneWidget);
      });

      testWidgets("a retried recording lands in the box", (tester) async {
        final composer = await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: mode);

        final gesture = await hold(tester: tester, mode: mode);
        await gesture.up();
        await tester.pump();
        await emitVoice(
          tester: tester,
          state: VoiceInputState.retryPending(error: VoiceTranscriptionError.networkError(innerError: null)),
        );
        await tester.pump(const Duration(milliseconds: 500));

        await tester.tap(find.text("Retry"));
        await tester.pump();
        verify(voiceCubit.retry).called(1);
        await emitVoice(
          tester: tester,
          state: VoiceInputState.retrying(previousError: VoiceTranscriptionError.networkError(innerError: null)),
        );
        await complete(tester: tester, transcript: "spoken words", outcome: VoiceDictationOutcome.finished);

        expect(composer.sent, isEmpty);
        expect(composer.finishes, [AnalyticsVoiceFinish.edited]);
        expect(find.text("spoken words"), findsOneWidget);
      });

      testWidgets("a staged command leaves with the words", (tester) async {
        final composer = await _pumpComposer(
          tester: tester,
          voiceCubit: voiceCubit,
          mode: mode,
          stagedCommand: const CommandInfo(
            name: "review",
            template: null,
            hints: null,
            description: null,
            agent: null,
            model: null,
            provider: null,
            source: null,
            subtask: null,
          ),
        );

        final gesture = await hold(tester: tester, mode: mode);
        await gesture.up();
        await tester.pump();
        await complete(tester: tester, transcript: "spoken words", outcome: VoiceDictationOutcome.finished);

        expect(composer.sent, [(text: "spoken words", command: "review")]);
        expect(composer.commandsCleared, 1);
        expect(composer.finishes, [AnalyticsVoiceFinish.sent]);
      });

      testWidgets("a hold the system cancels lands in the box instead of sending", (tester) async {
        final composer = await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: mode);

        final gesture = await hold(tester: tester, mode: mode);
        await gesture.cancel();
        await tester.pump();
        verify(() => voiceCubit.stopAndTranscribe(limitReached: false)).called(1);
        await complete(tester: tester, transcript: "spoken words", outcome: VoiceDictationOutcome.finished);

        expect(composer.sent, isEmpty);
        expect(composer.finishes, [AnalyticsVoiceFinish.edited]);
        expect(find.text("spoken words"), findsOneWidget);
      });

      testWidgets("assistive technology dismisses the hold surface to cancel", (tester) async {
        final semantics = tester.ensureSemantics();
        await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: mode);

        final gesture = await hold(tester: tester, mode: mode);
        tester.semantics.dismiss(find.semantics.byAction(SemanticsAction.dismiss));
        await tester.pump();

        verify(voiceCubit.cancel).called(1);
        await gesture.up();
        await tester.pump();
        verifyNever(() => voiceCubit.stopAndTranscribe(limitReached: false));
        semantics.dispose();
      });

      testWidgets("a dictation that sent itself does not raise the keyboard", (tester) async {
        await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: mode);

        final gesture = await hold(tester: tester, mode: mode);
        await gesture.up();
        await tester.pump();
        await complete(tester: tester, transcript: "spoken words", outcome: VoiceDictationOutcome.finished);

        final field = find.byType(EditableText);
        if (field.evaluate().isNotEmpty) {
          expect(tester.widget<EditableText>(field).focusNode.hasFocus, isFalse);
        }
      });
    });
  }

  testWidgets("a field that had the keyboard keeps it across a dictated send", (tester) async {
    final composer = await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: ChatInputMode.textFirst);
    await tester.tap(find.text("Follow up..."));
    await tester.pumpAndSettle();
    final focus = tester.widget<EditableText>(find.byType(EditableText)).focusNode;
    expect(focus.hasFocus, isTrue);

    final gesture = await hold(tester: tester, mode: ChatInputMode.textFirst);
    await gesture.up();
    await tester.pump();
    await complete(tester: tester, transcript: "spoken words", outcome: VoiceDictationOutcome.finished);

    expect(composer.sent, [(text: "spoken words", command: null)]);
    expect(focus.hasFocus, isTrue);
  });

  testWidgets("tapping send during transcribing still sends one message", (tester) async {
    final composer = await _pumpComposer(
      tester: tester,
      voiceCubit: voiceCubit,
      mode: ChatInputMode.textFirst,
      initialText: "Typed first",
    );

    final gesture = await hold(tester: tester, mode: ChatInputMode.textFirst);
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(TablerRegular.arrow_up));
    await tester.pump();
    expect(composer.sent, isEmpty, reason: "The box waits for the words on their way.");

    await complete(tester: tester, transcript: "and spoken", outcome: VoiceDictationOutcome.finished);
    expect(composer.sent, [(text: "Typed first and spoken", command: null)]);
  });

  testWidgets("the keyboard button during transcribing lands the words in the box", (tester) async {
    final composer = await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: ChatInputMode.voiceFirst);

    final gesture = await hold(tester: tester, mode: ChatInputMode.voiceFirst);
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(TablerRegular.keyboard));
    await tester.pump();
    await complete(tester: tester, transcript: "spoken words", outcome: VoiceDictationOutcome.finished);

    expect(composer.sent, isEmpty);
    expect(composer.finishes, [AnalyticsVoiceFinish.edited]);
    expect(find.text("spoken words"), findsOneWidget);
  });

  testWidgets("a tap on the pencil, from a second finger, ends in the box", (tester) async {
    final composer = await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: ChatInputMode.voiceFirst);

    final gesture = await hold(tester: tester, mode: ChatInputMode.voiceFirst);
    await tester.tap(find.byType(PregoVoiceTarget));
    await tester.pump();
    verify(() => voiceCubit.stopAndTranscribe(limitReached: false)).called(1);
    await gesture.up();
    await tester.pump();
    await complete(tester: tester, transcript: "spoken words", outcome: VoiceDictationOutcome.finished);

    expect(composer.sent, isEmpty);
    expect(find.text("spoken words"), findsOneWidget);
  });
}

/// The rest of the composer's chrome differs by mode; the hold starts on the
/// pill in voice-first and on the mic in text-first.
Finder _holdTarget({required ChatInputMode mode}) => switch (mode) {
  ChatInputMode.voiceFirst => find.textContaining("Hold to talk"),
  ChatInputMode.textFirst => find.byIcon(TablerRegular.microphone),
};

Future<_Composer> _pumpComposer({
  required WidgetTester tester,
  required VoiceInputCubit voiceCubit,
  required ChatInputMode mode,
  String initialText = "",
  bool canSend = true,
  CommandInfo? stagedCommand,
}) async {
  final composer = _Composer();
  final surfaceStyle = ValueNotifier(PregoComposerSurfaceStyle.emphasized);
  addTearDown(surfaceStyle.dispose);
  final attachmentDispatcher = ComposerAttachmentDispatcher(imagePicker: _NoOpComposerImagePicker());
  final imageClipboard = _NoOpImageClipboard();

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<VoiceInputCubit>.value(
        value: voiceCubit,
        child: ComposerPresentationScope(
          voiceSupport: ComposerVoiceSupport.supported,
          inputMode: mode,
          isKeyboardVisible: false,
          sendKeyPolicy: ComposerSendKeyPolicy.enterSends,
          presentation: ComposerPresentation.touch,
          attachmentDispatcher: () => attachmentDispatcher,
          imageClipboard: () => imageClipboard,
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: PromptInput(
                initialSelection: null,
                onBusyChanged: null,
                onSelectionChanged: null,
                isBusy: false,
                hasMessages: true,
                canSend: canSend,
                onSend: ({required draft, required command, required attachments}) {
                  composer.sent.add((text: draft.text, command: command));
                },
                onVoiceTranscriptionFinished: ({required finish}) => composer.finishes.add(finish),
                onDraftChanged: (_) {},
                onDraftCleared: () {},
                onAbort: () {},
                surfaceStyleController: surfaceStyle,
                composerHeader: null,
                composerTrailing: null,
                availableCommands: const [],
                stagedCommand: stagedCommand,
                onCommandSelected: (_) {},
                onCommandCleared: () => composer.commandsCleared++,
                attachmentsSupported: false,
                draftIdentity: "touch-voice-test",
                restorationKey: null,
                initialDraft: ComposerDraft.typed(text: initialText),
                initialAttachments: const [],
                onAttachmentsChanged: null,
                autofocus: false,
                onInitialAttachmentsConsumed: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return composer;
}

class _NoOpComposerImagePicker() implements ComposerImagePicker {
  @override
  Future<ComposerPickedImage?> pickImage() async => null;
}

class _NoOpImageClipboard() implements ImageClipboard {
  @override
  Future<Uint8List?> readImage() async => null;

  @override
  Future<void> writeImage({required Uint8List bytes}) async {}
}
