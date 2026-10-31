import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/sent_bubble_landing.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

class _MockVoiceInputCubit() extends MockCubit<VoiceInputState> implements VoiceInputCubit;

/// One way a composer can be set up, whose two layouts cross-fade in place.
typedef _Shell = ({String name, ChatInputMode mode, ComposerPresentation presentation});

/// One screen the layouts must line up on.
typedef _Screen = ({String name, double width, double textScale, TextDirection direction});

const _textFirstTouch = (
  name: "text-first touch",
  mode: ChatInputMode.textFirst,
  presentation: ComposerPresentation.touch,
);
const _voiceFirstTouch = (
  name: "voice-first touch",
  mode: ChatInputMode.voiceFirst,
  presentation: ComposerPresentation.touch,
);
const _textFirstPointer = (
  name: "text-first pointer",
  mode: ChatInputMode.textFirst,
  presentation: ComposerPresentation.pointer,
);

const List<_Screen> _screens = [
  (name: "390", width: 390, textScale: 1, direction: TextDirection.ltr),
  (name: "320 2x", width: 320, textScale: 2, direction: TextDirection.ltr),
  (name: "390 RTL", width: 390, textScale: 1, direction: TextDirection.rtl),
  (name: "320 2x RTL", width: 320, textScale: 2, direction: TextDirection.rtl),
];

/// The button or voice target wearing [icon], so its whole 44 pt is measured
/// rather than the glyph inside it.
Finder _control(IconData icon) => find.ancestor(
  of: find.byIcon(icon),
  matching: find.byWidgetPredicate((widget) => widget is PregoButtonsSolid || widget is PregoVoiceTarget),
);

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
    addTearDown(voiceStates.close);
    addTearDown(voiceCubit.close);
  });

  /// Where everything in one layout sits, from rest through a dictation.
  Future<Map<String, Rect>> measure({
    required WidgetTester tester,
    required _Shell shell,
    required _Screen screen,
    required bool typing,
  }) async {
    tester.view.physicalSize = Size(screen.width * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = screen.textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final rects = <String, Rect>{};
    void record(String name, Finder finder) {
      if (finder.evaluate().isNotEmpty) rects[name] = tester.getRect(finder.first);
    }

    // A stop shows only with nothing to send, so the busy typing layout is the
    // one a tap opens.
    await _pumpComposer(
      tester: tester,
      voiceCubit: voiceCubit,
      shell: shell,
      screen: screen,
      initialText: "",
      isBusy: true,
    );
    if (typing) {
      await tester.tap(switch (shell.mode) {
        ChatInputMode.voiceFirst => find.byTooltip("Type a message"),
        ChatInputMode.textFirst => find.text("Follow up..."),
      }, warnIfMissed: false);
      await tester.pumpAndSettle();
    }
    record("stop", _control(TablerSolid.player_stop));

    await _pumpComposer(
      tester: tester,
      voiceCubit: voiceCubit,
      shell: shell,
      screen: screen,
      initialText: typing ? "draft words" : "",
      isBusy: false,
    );
    rects["composer"] = tester.getRect(find.byType(PromptInput));
    record("options", find.byType(ComposerOptionsAccordion));
    record("mic", _control(TablerRegular.microphone));
    record("send", _control(TablerRegular.arrow_up));
    record("keyboard", _control(TablerRegular.keyboard));
    record("field", find.byType(TextField));
    record("expand", find.byIcon(TablerRegular.maximize));

    // Touch holds; a pointer shell clicks the mic.
    final pointer = shell.presentation == ComposerPresentation.pointer;
    TestGesture? hold;
    if (pointer) {
      await tester.tap(find.byTooltip("Record voice"));
    } else {
      final holdTarget = switch (shell.mode) {
        ChatInputMode.voiceFirst => find.textContaining("Hold to talk"),
        ChatInputMode.textFirst => find.byIcon(TablerRegular.microphone),
      };
      hold = await tester.startGesture(tester.getCenter(holdTarget));
    }
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    record("listening: pencil", _control(TablerRegular.pencil));
    record("listening: X", _control(TablerRegular.x));
    record("listening: waveform", find.byType(PregoVoiceWaveform));
    record("listening: wide Send", find.byType(PregoVoiceSendButton));
    record("listening: mic", _control(TablerRegular.microphone));
    record(
      "listening: wash",
      find.byWidgetPredicate(
        (widget) => switch (widget) {
          DecoratedBox(decoration: BoxDecoration(:final color)) =>
            color == PregoDesignSystem.light.colors.bgDestructivePressedAlt,
          _ => false,
        },
      ),
    );

    if (hold != null) {
      await hold.up();
    } else {
      await tester.tap(find.byType(PregoVoiceSendButton));
    }
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    record("transcribing: X", _control(TablerRegular.x));
    record("transcribing: words", find.text("Transcribing..."));

    voiceStates.add(
      const VoiceInputState.completed(
        transcript: "spoken words",
        outcome: VoiceDictationOutcome.finished,
        mode: VoiceDictationMode.afterRecording,
      ),
    );
    await tester.pump();
    await tester.pump();
    voiceStates.add(const VoiceInputState.idle());
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    return rects;
  }

  for (final shell in [_textFirstTouch, _textFirstPointer]) {
    for (final screen in _screens) {
      testWidgets("${shell.name}, ${screen.name}: every control keeps its place between the layouts", (tester) async {
        final resting = await measure(tester: tester, shell: shell, screen: screen, typing: false);
        final typing = await measure(tester: tester, shell: shell, screen: screen, typing: true);

        final shared = {...resting.keys}.intersection({...typing.keys})..remove("composer");
        expect(
          shared,
          containsAll([
            "stop",
            "options",
            "mic",
            "send",
            "listening: pencil",
            "listening: waveform",
            "listening: mic",
            "listening: wash",
            "transcribing: X",
            if (shell.presentation == ComposerPresentation.pointer) ...["listening: X", "listening: wide Send"],
          ]),
        );
        for (final name in shared) {
          expect(typing[name], resting[name], reason: name);
        }
      });
    }
  }

  for (final screen in _screens) {
    testWidgets("voice-first touch, ${screen.name}: the typing layout's nested pill ends 12 pt from its edge", (
      tester,
    ) async {
      final rects = await measure(tester: tester, shell: _voiceFirstTouch, screen: screen, typing: true);

      double fromEdge({required Rect? control, required bool atStart}) {
        if (control == null) fail("The control was not on screen.");
        final fromLeft = atStart == (screen.direction == TextDirection.ltr);
        return fromLeft ? control.left : screen.width - control.right;
      }

      expect(fromEdge(control: rects["options"], atStart: true), 12);
      expect(fromEdge(control: rects["send"], atStart: false), 12);
    });
  }

  for (final shell in [_textFirstTouch, _voiceFirstTouch, _textFirstPointer]) {
    testWidgets("${shell.name}: the typing layout's field stays clear of the border", (tester) async {
      final rects = await measure(tester: tester, shell: shell, screen: _screens.first, typing: true);

      final field = rects["field"];
      if (field == null) fail("The field was not on screen.");
      expect(field.left, PregoSpacing.sm + 1 + PregoSpacing.xs);
    });
  }
}

Future<void> _pumpComposer({
  required WidgetTester tester,
  required VoiceInputCubit voiceCubit,
  required _Shell shell,
  required _Screen screen,
  required String initialText,
  required bool isBusy,
}) async {
  final surfaceStyle = ValueNotifier(PregoComposerSurfaceStyle.emphasized);
  addTearDown(surfaceStyle.dispose);
  final attachmentDispatcher = ComposerAttachmentDispatcher(imagePicker: _NoOpComposerImagePicker());
  final imageClipboard = _NoOpImageClipboard();

  await tester.pumpWidget(
    MaterialApp(
      // A fresh composer for each measuring pass, with no state carried over.
      key: UniqueKey(),
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => Directionality(
        textDirection: screen.direction,
        child: SentBubbleLanding(child: child ?? const SizedBox.shrink()),
      ),
      home: BlocProvider<VoiceInputCubit>.value(
        value: voiceCubit,
        child: ComposerPresentationScope(
          voiceSupport: ComposerVoiceSupport.supported,
          inputMode: shell.mode,
          isKeyboardVisible: false,
          sendKeyPolicy: ComposerSendKeyPolicy.enterSends,
          presentation: shell.presentation,
          attachmentDispatcher: () => attachmentDispatcher,
          imageClipboard: () => imageClipboard,
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: PromptInput(
                initialSelection: null,
                onBusyChanged: null,
                onSelectionChanged: null,
                isBusy: isBusy,
                hasMessages: true,
                canSend: true,
                onSend: ({required draft, required command, required attachments}) {},
                onVoiceTranscriptionFinished: ({required finish, required mode}) {},
                onDraftChanged: (_) {},
                onDraftCleared: () {},
                onAbort: () {},
                surfaceStyleController: surfaceStyle,
                composerHeader: null,
                composerTrailing: null,
                availableCommands: const [],
                stagedCommand: null,
                onCommandSelected: (_) {},
                onCommandCleared: () {},
                attachmentsSupported: false,
                draftIdentity: "layouts-line-up-test",
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
