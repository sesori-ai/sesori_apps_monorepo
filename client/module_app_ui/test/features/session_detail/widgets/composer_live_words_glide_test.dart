import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/composer_live_words.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/sent_bubble_landing.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockVoiceInputCubit() extends MockCubit<VoiceInputState> implements VoiceInputCubit;

const _words = LiveWords(confirmed: "spoken words", provisional: "");
const _tentativeWords = LiveWords(confirmed: "spoken ", provisional: "words");
const _tentativeStart = 0.46;
const _brighten = Duration(milliseconds: 280);
const _flight = Duration(milliseconds: 340);
const _handOver = Duration(milliseconds: 90);
const _frame = Duration(milliseconds: 16);
final _isClearShadow = predicate<BoxShadow>((shadow) => shadow.color.a == 0, "a clear shadow");

final _glide = find.byKey(composerLiveWordsGlideKey);
final _bubble = find.byType(UserMessageBubble);
final _field = find.byType(TextField);

Finder get _glideText => find.descendant(of: _glide, matching: find.byType(RichText));

double _glideOpacity(WidgetTester tester) =>
    tester.widget<Opacity>(find.descendant(of: _glide, matching: find.byType(Opacity))).opacity;

/// How opaque the span showing exactly [text] is, against the opaque text colour.
double _opacityOf({required InlineSpan span, required String text}) {
  double? opacity;
  span.visitChildren((child) {
    if (child is TextSpan && child.text == text) opacity = child.style?.color?.a;
    return opacity == null;
  });
  return opacity ?? (throw StateError('No span shows "$text"'));
}

double _tentativeOpacity(WidgetTester tester) =>
    _opacityOf(span: tester.widget<RichText>(_glideText).text, text: _tentativeWords.provisional);

String _glideString(WidgetTester tester) => tester.widget<RichText>(_glideText).text.toPlainText();

RenderLandingSlot _slotOf(WidgetTester tester, Finder child) =>
    tester.renderObject<RenderLandingSlot>(find.ancestor(of: child, matching: find.byType(ComposerWordsBoxSlot)));

RenderLandingSlot _bubbleSlot(WidgetTester tester) =>
    tester.renderObject<RenderLandingSlot>(find.descendant(of: _bubble, matching: find.byType(SentBubbleSlot)));

/// The surface of the bubble, inside its row's margins, as the words end on it.
Rect _bubbleRect(WidgetTester tester) => UserMessageBubble.margin.deflateRect(
  tester.getRect(find.descendant(of: _bubble, matching: find.byType(SentBubbleSlot))),
);

Matcher _aboutSize(Size size) => predicate<Size>(
  (actual) => (actual.width - size.width).abs() < 0.01 && (actual.height - size.height).abs() < 0.01,
  "about $size",
);

void _expectRect(Rect actual, Rect expected) {
  expect(actual.left, moreOrLessEquals(expected.left, epsilon: 0.01));
  expect(actual.top, moreOrLessEquals(expected.top, epsilon: 0.01));
  expect(actual.right, moreOrLessEquals(expected.right, epsilon: 0.01));
  expect(actual.bottom, moreOrLessEquals(expected.bottom, epsilon: 0.01));
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
    when(voiceCubit.cancel).thenAnswer((_) async {});
    when(voiceCubit.acknowledgeOutcome).thenAnswer((_) {
      voiceStates.add(const VoiceInputState.idle());
    });
    addTearDown(voiceStates.close);
    addTearDown(voiceCubit.close);
  });

  /// Holds, says the words and settles them on screen.
  Future<TestGesture> hold({
    required WidgetTester tester,
    VoiceLivePresentation presentation = VoiceLivePresentation.focus,
    LiveWords words = _words,
  }) async {
    when(() => voiceCubit.stopAndTranscribe(limitReached: false)).thenAnswer((_) async {
      voiceStates.add(VoiceInputState.liveFinishing(words: words, presentation: presentation));
    });
    final gesture = await tester.startGesture(tester.getCenter(find.textContaining("Hold to talk")));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    voiceStates.add(VoiceInputState.liveRecording(words: words, presentation: presentation));
    await tester.pump();
    await tester.pump();
    // Long enough to show them, not for a word that hasn't changed to brighten.
    await tester.pump(const Duration(milliseconds: 500));
    return gesture;
  }

  /// The words are done. The next frame is the glide's first; nothing has moved.
  Future<void> complete({
    required WidgetTester tester,
    VoiceDictationOutcome outcome = VoiceDictationOutcome.finished,
    VoiceDictationMode mode = VoiceDictationMode.live,
    String transcript = "spoken words",
  }) async {
    voiceStates.add(VoiceInputState.completed(transcript: transcript, outcome: outcome, mode: mode));
    await tester.pump(Duration.zero);
  }

  Future<void> send({required WidgetTester tester, required TestGesture gesture}) async {
    await gesture.up();
    await tester.pump();
    await complete(tester: tester);
  }

  /// Holds, slides onto the pencil and lets go.
  Future<void> edit({required WidgetTester tester, required TestGesture gesture}) async {
    await gesture.moveTo(tester.getCenter(find.byType(PregoVoiceTarget)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pump();
    await complete(tester: tester);
  }

  group("to the bubble", () {
    testWidgets("the bubble is built hidden, and the words end exactly on it", (tester) async {
      await _pumpScreen(tester: tester, voiceCubit: voiceCubit);
      final gesture = await hold(tester: tester);
      final start = tester.getRect(find.byType(LiveWordsText));

      await send(tester: tester, gesture: gesture);
      // Nothing has moved while the row was being built.
      expect(_bubbleSlot(tester).hidden, isTrue);
      expect(_bubbleSlot(tester), paintsNothing);
      expect(tester.getRect(_glide).left, lessThanOrEqualTo(start.left));
      expect(_glideString(tester), "spoken words");

      await tester.pump();
      await tester.pump(_flight ~/ 2);
      final midway = tester.getRect(_glide);
      expect(midway.left, greaterThan(start.left));
      expect(_bubbleSlot(tester).hidden, isTrue);
      expect(_glideString(tester), wrapDictatedText(text: "spoken words"));

      await tester.pump(_flight ~/ 2);
      _expectRect(tester.getRect(_glide), _bubbleRect(tester));

      await tester.pump(_handOver);
      expect(_bubbleSlot(tester), isNot(paintsNothing));
    });

    testWidgets("the words follow the row when it moves under them", (tester) async {
      final screen = await _pumpScreen(tester: tester, voiceCubit: voiceCubit);
      final gesture = await hold(tester: tester);
      await send(tester: tester, gesture: gesture);
      await tester.pump();
      await tester.pump(_flight ~/ 2);

      final before = _bubbleRect(tester);
      screen.moveRows(by: 40);
      await tester.pump();
      // The layer lays out before the list does, so it follows a frame behind.
      await tester.pump(_flight ~/ 2);

      expect(_bubbleRect(tester).top, lessThan(before.top));
      _expectRect(tester.getRect(_glide), _bubbleRect(tester));
    });

    testWidgets("exactly one copy shows on every frame", (tester) async {
      await _pumpScreen(tester: tester, voiceCubit: voiceCubit);
      final gesture = await hold(tester: tester);
      await send(tester: tester, gesture: gesture);
      await tester.pump();

      var frames = 0;
      while (_glide.evaluate().isNotEmpty) {
        final slot = _bubbleSlot(tester);
        // While both are up they are one image: the words sit on the bubble.
        if (!slot.hidden) _expectRect(tester.getRect(_glide), _bubbleRect(tester));
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
      }
      expect(frames, greaterThan(20));
      expect(_bubbleSlot(tester).hidden, isFalse);
      expect(find.byType(LiveWordsText), findsNothing);
    });

    testWidgets("the bubble shows and the words fade over it, then the layer closes", (tester) async {
      await _pumpScreen(tester: tester, voiceCubit: voiceCubit);
      final gesture = await hold(tester: tester);
      await send(tester: tester, gesture: gesture);
      await tester.pump();
      await tester.pump(_flight - const Duration(milliseconds: 16));
      expect(_bubbleSlot(tester).hidden, isTrue);
      expect(_glideOpacity(tester), 1);

      await tester.pump(const Duration(milliseconds: 32));
      expect(_bubbleSlot(tester).hidden, isFalse);
      expect(_glideOpacity(tester), inExclusiveRange(0, 1));

      await tester.pump(_handOver + _frame);
      expect(_glide, findsNothing);
      final portal = find.descendant(of: find.byType(ComposerLiveWords), matching: find.byType(OverlayPortal)).first;
      expect(tester.widget<OverlayPortal>(portal).controller.isShowing, isFalse);
    });

    testWidgets("nothing else in the screen moves or rebuilds on the way", (tester) async {
      await _pumpScreen(tester: tester, voiceCubit: voiceCubit);
      final gesture = await hold(tester: tester);
      await send(tester: tester, gesture: gesture);
      await tester.pump();
      await tester.pump(_flight ~/ 4);

      final composer = find.byType(PromptInput);
      final top = tester.getTopLeft(composer);
      final rows = tester.getTopLeft(_bubble);
      final body = find.descendant(of: composer, matching: find.textContaining("Hold to talk"));
      final widget = tester.widget(body);

      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      expect(tester.getTopLeft(composer), top);
      expect(tester.getTopLeft(_bubble), rows);
      // The same instance means the composer's build never ran for the glide.
      expect(identical(tester.widget(body), widget), isTrue);
    });

    testWidgets("a row re-building its bubble mid-glide keeps the words on it", (tester) async {
      final screen = await _pumpScreen(tester: tester, voiceCubit: voiceCubit);
      final gesture = await hold(tester: tester);
      await send(tester: tester, gesture: gesture);
      await tester.pump();
      await tester.pump(_flight ~/ 2);

      screen.echoRows();
      await tester.pump();
      expect(_bubbleSlot(tester).hidden, isTrue, reason: "The echo's bubble takes over the wait.");

      await tester.pump(_flight ~/ 2);
      _expectRect(tester.getRect(_glide), _bubbleRect(tester));
    });

    testWidgets("an old row built during the wait isn't taken for the new one", (tester) async {
      await _pumpScreen(tester: tester, voiceCubit: voiceCubit, rowsArrive: false);
      final gesture = await hold(tester: tester);
      await send(tester: tester, gesture: gesture);
      await tester.pump();
      await tester.pump();

      expect(_bubbleSlot(tester).hidden, isFalse);
    });

    testWidgets("a row that goes away leaves the words to finish where it was", (tester) async {
      final screen = await _pumpScreen(tester: tester, voiceCubit: voiceCubit);
      final gesture = await hold(tester: tester);
      await send(tester: tester, gesture: gesture);
      await tester.pump();
      await tester.pump(_flight ~/ 2);
      final target = _bubbleRect(tester);

      screen.clearRows();
      await tester.pump(_flight ~/ 2);
      _expectRect(tester.getRect(_glide), target);

      await tester.pump(_handOver + _frame);
      expect(_glide, findsNothing);
    });

    testWidgets("after a recording there is no glide and the bubble shows at once", (tester) async {
      await _pumpScreen(tester: tester, voiceCubit: voiceCubit);
      when(() => voiceCubit.stopAndTranscribe(limitReached: false)).thenAnswer((_) async {
        voiceStates.add(const VoiceInputState.transcribing(limitReached: false));
      });
      final gesture = await tester.startGesture(tester.getCenter(find.textContaining("Hold to talk")));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pump();
      await complete(tester: tester, mode: VoiceDictationMode.afterRecording);

      expect(_glide, findsNothing);
      expect(_bubbleSlot(tester).hidden, isFalse);
    });
  });

  group("when no bubble is built", () {
    testWidgets("the words wait two frames, then glide above the composer and fade", (tester) async {
      await _pumpScreen(tester: tester, voiceCubit: voiceCubit, buildsRows: false);
      final gesture = await hold(tester: tester);
      final start = tester.getRect(find.byType(LiveWordsText));
      await send(tester: tester, gesture: gesture);
      expect(_glideOpacity(tester), 1);

      // The second frame still holds them; the row could yet be built. The next is
      // the glide's first, and a controller's first tick has no time on it.
      await tester.pump(_frame);
      await tester.pump(_frame);
      expect(tester.getRect(_glide).left, lessThanOrEqualTo(start.left));
      expect(_glideOpacity(tester), 1);

      await tester.pump();
      await tester.pump(_flight ~/ 2);
      final composer = tester.getRect(find.byType(ComposerLiveWords));
      final midway = tester.getRect(_glide);
      expect(midway.left, greaterThan(start.left));
      expect(_glideOpacity(tester), inExclusiveRange(0, 1));

      await tester.pump(_flight ~/ 2);
      final end = tester.getRect(_glide);
      expect(end.right, moreOrLessEquals(composer.right - UserMessageBubble.margin.right));
      expect(end.bottom, lessThan(composer.top));
      expect(_glideOpacity(tester), 0);

      await tester.pump(_handOver + _frame);
      expect(_glide, findsNothing);
    });

    testWidgets("a bubble built afterwards isn't kept hidden", (tester) async {
      final screen = await _pumpScreen(tester: tester, voiceCubit: voiceCubit, buildsRows: false);
      final gesture = await hold(tester: tester);
      await send(tester: tester, gesture: gesture);
      await tester.pump();
      await tester.pump();

      screen.addRowLate(text: "spoken words");
      await tester.pump();
      expect(_bubbleSlot(tester).hidden, isFalse);
    });
  });

  group("to the box", () {
    testWidgets("the field holds its text back until the words reach it", (tester) async {
      await _pumpScreen(tester: tester, voiceCubit: voiceCubit);
      final gesture = await hold(tester: tester);
      await edit(tester: tester, gesture: gesture);
      expect(_slotOf(tester, _field).hidden, isTrue);

      await tester.pump();
      await tester.pump(_flight ~/ 2);
      expect(_slotOf(tester, _field).hidden, isTrue);
      expect(_glideString(tester), "spoken words");

      await tester.pump(_flight ~/ 2);
      _expectRect(tester.getRect(_glide), tester.getRect(_field));
      expect(_slotOf(tester, _field).hidden, isFalse);

      await tester.pump(_handOver + _frame);
      expect(_glide, findsNothing);
      expect(find.text("spoken words"), findsOneWidget);
      expect(_bubble, findsNothing);
    });

    testWidgets("the composer doesn't rebuild while they fly", (tester) async {
      await _pumpScreen(tester: tester, voiceCubit: voiceCubit);
      final gesture = await hold(tester: tester);
      await edit(tester: tester, gesture: gesture);
      await tester.pump();
      await tester.pump(_flight ~/ 2);

      final field = tester.widget(_field);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(identical(tester.widget(_field), field), isTrue);
    });

    testWidgets("a cut-off dictation lands there too, and isn't sent", (tester) async {
      await _pumpScreen(tester: tester, voiceCubit: voiceCubit);
      final gesture = await hold(tester: tester);
      await gesture.up();
      await tester.pump();
      await complete(tester: tester, outcome: VoiceDictationOutcome.interrupted);
      await tester.pump();
      await tester.pump(_flight);

      _expectRect(tester.getRect(_glide), tester.getRect(_field));
      expect(_bubble, findsNothing);
    });

    testWidgets("a cut-off's tentative words brighten on the way, as a release's do", (tester) async {
      await _pumpScreen(tester: tester, voiceCubit: voiceCubit);
      final gesture = await hold(tester: tester, words: _tentativeWords);

      // The connection goes with the finger still down: there was no release.
      await complete(tester: tester, outcome: VoiceDictationOutcome.interrupted);
      expect(_tentativeOpacity(tester), moreOrLessEquals(_tentativeStart, epsilon: 0.01));
      await tester.pump();
      expect(_tentativeOpacity(tester), moreOrLessEquals(_tentativeStart, epsilon: 0.01));
      await tester.pump();

      await tester.pump(_brighten ~/ 2);
      final midway = _tentativeOpacity(tester);
      expect(midway, inExclusiveRange(_tentativeStart + 0.1, 0.95));
      await tester.pump(_frame);
      expect(_tentativeOpacity(tester), greaterThan(midway));

      await tester.pump(_brighten ~/ 2);
      expect(_tentativeOpacity(tester), 1);
      await gesture.up();
    });

    testWidgets("words that finish mid-brighten carry on from where they were", (tester) async {
      await _pumpScreen(tester: tester, voiceCubit: voiceCubit);
      final gesture = await hold(tester: tester, words: _tentativeWords);
      await gesture.up();
      await tester.pump();
      await tester.pump();
      await tester.pump(_brighten ~/ 2);
      final released = tester.widget<RichText>(
        find.descendant(of: find.byType(LiveWordsText), matching: find.byType(RichText)),
      );
      final atRelease = _opacityOf(span: released.text, text: _tentativeWords.provisional);
      expect(atRelease, inExclusiveRange(_tentativeStart + 0.1, 0.95));

      await complete(tester: tester, outcome: VoiceDictationOutcome.interrupted);
      expect(_tentativeOpacity(tester), moreOrLessEquals(atRelease, epsilon: 0.01));
    });

    testWidgets("each word sets off as bright as it was, settled or dim or part way", (tester) async {
      await _pumpScreen(tester: tester, voiceCubit: voiceCubit);
      const first = LiveWords(confirmed: "", provisional: "spoken ");
      final gesture = await hold(tester: tester, words: first);
      voiceStates.add(
        const VoiceInputState.liveRecording(
          words: LiveWords(confirmed: "", provisional: "spoken words"),
          presentation: VoiceLivePresentation.focus,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 310));
      await tester.pump(const Duration(milliseconds: 140));

      InlineSpan live() => tester
          .widget<RichText>(find.descendant(of: find.byType(LiveWordsText), matching: find.byType(RichText)))
          .text;
      final partWay = _opacityOf(span: live(), text: "spoken ");
      expect(partWay, inExclusiveRange(_tentativeStart + 0.1, 0.95));
      expect(_opacityOf(span: live(), text: "words"), moreOrLessEquals(_tentativeStart, epsilon: 0.01));

      await complete(tester: tester, outcome: VoiceDictationOutcome.interrupted);
      final span = tester.widget<RichText>(_glideText).text;
      expect(_opacityOf(span: span, text: "spoken "), moreOrLessEquals(partWay, epsilon: 0.01));
      expect(_tentativeOpacity(tester), moreOrLessEquals(_tentativeStart, epsilon: 0.01));
      await gesture.up();
    });

    testWidgets("spacing around the words stays out of the landing, whatever their brightness", (tester) async {
      await _pumpScreen(tester: tester, voiceCubit: voiceCubit);
      const spaced = LiveWords(confirmed: " spoken ", provisional: "words ");
      final gesture = await hold(tester: tester, words: spaced);
      await complete(tester: tester, outcome: VoiceDictationOutcome.interrupted);
      await tester.pump();
      await tester.pump();
      await tester.pump(_flight ~/ 2);

      expect(_glideString(tester), "spoken words");
      final span = tester.widget<RichText>(_glideText).text;
      expect(_opacityOf(span: span, text: "spoken "), 1);
      expect(_opacityOf(span: span, text: "words"), lessThan(1));
      await gesture.up();
    });

    testWidgets("words heard in the very frame the dictation ends fly with the rest", (tester) async {
      await _pumpScreen(tester: tester, voiceCubit: voiceCubit);
      final gesture = await hold(
        tester: tester,
        words: const LiveWords(confirmed: "", provisional: "spoken "),
      );
      voiceStates
        ..add(const VoiceInputState.liveRecording(words: _tentativeWords, presentation: VoiceLivePresentation.focus))
        ..add(
          const VoiceInputState.completed(
            transcript: "spoken words",
            outcome: VoiceDictationOutcome.interrupted,
            mode: VoiceDictationMode.live,
          ),
        );
      await tester.pump(Duration.zero);

      expect(_glideString(tester), "spoken words");
      await gesture.up();
    });

    testWidgets("words with no words to land fade as they did", (tester) async {
      await _pumpScreen(tester: tester, voiceCubit: voiceCubit);
      final gesture = await hold(tester: tester);
      await gesture.up();
      await tester.pump();
      await complete(tester: tester, transcript: " ");
      await tester.pump(const Duration(milliseconds: 120));

      expect(_glide, findsNothing);
      expect(find.byType(LiveWordsText), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 240));
      expect(find.byType(LiveWordsText), findsNothing);
    });
  });

  testWidgets("the owner going mid-glide takes the words and releases the bubble", (tester) async {
    final screen = await _pumpScreen(tester: tester, voiceCubit: voiceCubit);
    final gesture = await hold(tester: tester);
    await send(tester: tester, gesture: gesture);
    await tester.pump();
    await tester.pump(_flight ~/ 2);
    expect(_bubbleSlot(tester).hidden, isTrue);

    screen.removeComposer();
    await tester.pump();

    expect(_glide, findsNothing);
    expect(_bubbleSlot(tester).hidden, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets("another hold right after a send doesn't wait for the words", (tester) async {
    await _pumpScreen(tester: tester, voiceCubit: voiceCubit);
    final gesture = await hold(tester: tester);
    await send(tester: tester, gesture: gesture);
    await tester.pump();
    await tester.pump(_flight ~/ 2);

    await tester.startGesture(tester.getCenter(find.textContaining("Hold to talk").last));
    voiceStates.add(
      const VoiceInputState.liveRecording(words: LiveWords.none, presentation: VoiceLivePresentation.focus),
    );
    await tester.pump(Duration.zero);

    expect(_glide, findsNothing);
    expect(_bubbleSlot(tester).hidden, isFalse);
    expect(find.byType(LiveWordsText), findsOneWidget);
  });

  group("reduced motion", () {
    testWidgets("nothing travels: the words fade where they stand and the bubble is there", (tester) async {
      await _pumpScreen(tester: tester, voiceCubit: voiceCubit, disableAnimations: true);
      final gesture = await hold(tester: tester);
      final top = tester.getTopLeft(find.byType(LiveWordsText));
      await send(tester: tester, gesture: gesture);
      await tester.pump();

      expect(_glide, findsNothing);
      expect(_bubbleSlot(tester).hidden, isFalse);
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.getTopLeft(find.byType(LiveWordsText)), top);

      final dim = find.descendant(of: find.byKey(composerLiveWordsDimKey), matching: find.byType(FadeTransition));
      expect(tester.widget<FadeTransition>(dim).opacity.value, inExclusiveRange(0, 1));
    });
  });

  testWidgets("a panel's shadow fades where it is, rather than shrinking into a hard plate", (tester) async {
    await _pumpScreen(tester: tester, voiceCubit: voiceCubit);
    final gesture = await hold(tester: tester, presentation: VoiceLivePresentation.panel);
    await send(tester: tester, gesture: gesture);
    List<BoxShadow> shadows() {
      final surface = tester.widget<DecoratedBox>(find.descendant(of: _glide, matching: find.byType(DecoratedBox)));
      return (surface.decoration as BoxDecoration).boxShadow ?? const [];
    }

    final atRest = shadows();
    expect(atRest, isNotEmpty);
    await tester.pump();
    await tester.pump(_flight ~/ 2);
    final midway = shadows();
    expect(midway.first.blurRadius, atRest.first.blurRadius);
    expect(midway.first.color.a, lessThan(atRest.first.color.a));
  });

  testWidgets("the words change face and wrap while moving fast, never as they land", (tester) async {
    await _pumpScreen(tester: tester, voiceCubit: voiceCubit);
    final gesture = await hold(tester: tester);
    await send(tester: tester, gesture: gesture);
    final heavy = tester.widget<RichText>(_glideText).text.style?.fontWeight;
    final FontWeight? landing = buildChatMessageMarkdownStyleSheet(prego: PregoDesignSystem.light).p?.fontWeight;
    expect(heavy, isNot(landing));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final paragraph = tester.renderObject<RenderParagraph>(_glideText);
    final laidOut = paragraph.size;
    expect(tester.widget<RichText>(_glideText).text.style?.fontWeight, landing);

    // From here it only scales: the very same layout, down to its last frame.
    for (var i = 0; i < 12; i++) {
      await tester.pump(_frame);
      expect(tester.renderObject<RenderParagraph>(_glideText).size, laidOut);
    }
    await tester.pump(_flight - const Duration(milliseconds: 80) - _frame * 12);
    expect(tester.getSize(_glideText), _aboutSize(laidOut));
  });

  testWidgets("a panel's surface turns into the bubble's", (tester) async {
    await _pumpScreen(tester: tester, voiceCubit: voiceCubit);
    final gesture = await hold(tester: tester, presentation: VoiceLivePresentation.panel);
    await send(tester: tester, gesture: gesture);
    await tester.pump();
    await tester.pump(_flight);

    final surface = tester.widget<DecoratedBox>(find.descendant(of: _glide, matching: find.byType(DecoratedBox)));
    expect((surface.decoration as BoxDecoration).color, PregoDesignSystem.light.colors.bgSurface2);
    expect((surface.decoration as BoxDecoration).boxShadow, everyElement(_isClearShadow));
  });
}

Future<_ScreenState> _pumpScreen({
  required WidgetTester tester,
  required VoiceInputCubit voiceCubit,
  bool buildsRows = true,
  bool rowsArrive = true,
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
        child: child ?? const SizedBox.shrink(),
      ),
      home: BlocProvider<VoiceInputCubit>.value(
        value: voiceCubit,
        child: ComposerPresentationScope(
          voiceSupport: ComposerVoiceSupport.supported,
          inputMode: ChatInputMode.voiceFirst,
          isKeyboardVisible: false,
          sendKeyPolicy: ComposerSendKeyPolicy.enterSends,
          presentation: ComposerPresentation.touch,
          attachmentDispatcher: () => ComposerAttachmentDispatcher(imagePicker: _NoOpComposerImagePicker()),
          imageClipboard: _NoOpImageClipboard.new,
          child: _Screen(buildsRows: buildsRows, rowsArrive: rowsArrive),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return tester.state<_ScreenState>(find.byType(_Screen));
}

/// A session screen reduced to what the words touch: a landing over a list of
/// bubbles and a composer whose send adds to them.
class const _Screen({required final bool buildsRows, required final bool rowsArrive}) extends StatefulWidget {
  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState() extends State<_Screen> {
  final _surfaceStyle = ValueNotifier(PregoComposerSurfaceStyle.emphasized);
  final List<String> _rows = [];
  double _rowsLift = 0;
  bool _echoed = false;
  bool _composerGone = false;

  void moveRows({required double by}) => setState(() => _rowsLift = by);
  void echoRows() => setState(() => _echoed = true);
  void clearRows() => setState(_rows.clear);
  void removeComposer() => setState(() => _composerGone = true);
  void addRowLate({required String text}) => setState(() => _rows.add(text));

  @override
  void dispose() {
    _surfaceStyle.dispose();
    super.dispose();
  }

  Widget _row({required String text}) {
    final bubble = UserMessageBubble(
      markdown: wrapDictatedText(text: text),
      attachments: const [],
      outlined: false,
      transitionDuration: Duration.zero,
    );
    // An echo's bubble sits under a different parent, as the message's own does.
    return SentBubbleArrival(
      arriving: widget.rowsArrive && !_echoed,
      child: _echoed ? Padding(padding: EdgeInsets.zero, child: bubble) : bubble,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SentBubbleLanding(
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: _rowsLift),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [for (final text in _rows) _row(text: text)],
                  ),
                ),
              ),
            ),
            if (!_composerGone)
              PromptInput(
                initialSelection: null,
                onBusyChanged: null,
                onSelectionChanged: null,
                isBusy: false,
                hasMessages: true,
                canSend: true,
                onSend: ({required draft, required command, required attachments}) {
                  if (widget.buildsRows) setState(() => _rows.add(draft.text));
                },
                onVoiceTranscriptionFinished: ({required finish, required mode}) {},
                onDraftChanged: (_) {},
                onDraftCleared: () {},
                onAbort: () {},
                surfaceStyleController: _surfaceStyle,
                composerHeader: null,
                composerTrailing: null,
                availableCommands: const [],
                stagedCommand: null,
                onCommandSelected: (_) {},
                onCommandCleared: () {},
                attachmentsSupported: false,
                draftIdentity: "glide-test",
                restorationKey: null,
                initialDraft: ComposerDraft.typed(text: ""),
                initialAttachments: const [],
                onAttachmentsChanged: null,
                autofocus: false,
                onInitialAttachmentsConsumed: () {},
              ),
          ],
        ),
      ),
    );
  }
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
