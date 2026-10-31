import "dart:async";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/composer_live_words.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/sent_bubble_landing.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

class _MockVoiceInputCubit() extends MockCubit<VoiceInputState> implements VoiceInputCubit;

const _focus = VoiceLivePresentation.focus;
const _panel = VoiceLivePresentation.panel;
const _releaseToSend = "Release to send · slide up to cancel";

/// Enough to wrap well past any room the layer has at the test window's size.
final String _longText = List.filled(240, "word ").join();

const _screen = Size(800, 600);

final _words = find.byType(LiveWordsText);
final _dim = find.byKey(composerLiveWordsDimKey);
final _paragraph = find.descendant(of: _words, matching: find.byType(RichText));

/// The fade the slide-out scrubs; the one nearest the words.
AnimatedOpacity _scrub(WidgetTester tester) =>
    tester.widget(find.ancestor(of: _words, matching: find.byType(AnimatedOpacity)).first);

/// The presence fade around the words.
double _wordsPresence(WidgetTester tester) =>
    tester.widget<Opacity>(find.ancestor(of: _words, matching: find.byType(Opacity)).first).opacity;

/// How far the words have dropped or risen from where they rest.
double _wordsTravel(WidgetTester tester) => tester
    .widget<Transform>(find.ancestor(of: _words, matching: find.byType(Transform)).first)
    .transform
    .getTranslation()
    .y;

double _dimOpacity(WidgetTester tester) =>
    tester.widget<FadeTransition>(find.descendant(of: _dim, matching: find.byType(FadeTransition))).opacity.value;

/// The alpha [word] paints with.
double _alphaOf(WidgetTester tester, {required String word}) {
  final root = tester.widget<RichText>(_paragraph).text as TextSpan;
  final span = (root.children ?? const <InlineSpan>[]).cast<TextSpan>().firstWhere(
    (span) => span.text?.contains(word) ?? false,
  );
  final color = span.style?.color;
  if (color == null) throw StateError("$word has no colour");
  return color.a;
}

/// Where the words' first line sits. Follows the paragraph, not the clip around
/// it, so it moves when the words do.
Offset _paragraphTop(WidgetTester tester) => tester.getTopLeft(_paragraph);

void main() {
  late StreamController<VoiceInputState> voiceStates;
  late _MockVoiceInputCubit voiceCubit;

  setUp(() {
    voiceStates = StreamController<VoiceInputState>();
    voiceCubit = _MockVoiceInputCubit();
    whenListen(voiceCubit, voiceStates.stream, initialState: const VoiceInputState.idle());
    when(() => voiceCubit.amplitudeStream).thenAnswer((_) => const Stream<double>.empty());
    when(voiceCubit.startRecording).thenAnswer((_) async {});
    when(() => voiceCubit.stopAndTranscribe(limitReached: false)).thenAnswer((_) async {});
    when(voiceCubit.cancel).thenAnswer((_) async {});
    when(voiceCubit.acknowledgeOutcome).thenAnswer((_) {});
  });

  // Not awaited: a stream nothing ever listened to never finishes closing.
  tearDown(() => unawaited(voiceStates.close()));

  Future<void> emit({required WidgetTester tester, required VoiceInputState state}) async {
    voiceStates.add(state);
    await tester.pump();
    await tester.pump();
  }

  Future<void> live({
    required WidgetTester tester,
    required VoiceLivePresentation presentation,
    String confirmed = "",
    String provisional = "",
  }) => emit(
    tester: tester,
    state: VoiceInputState.liveRecording(
      words: LiveWords(confirmed: confirmed, provisional: provisional),
      presentation: presentation,
    ),
  );

  /// Lets the layer's entrance, a word's fade and a rise all end. The waveform
  /// never settles, so frames are pumped explicitly.
  Future<void> settle(WidgetTester tester) => tester.pump(const Duration(seconds: 1));

  group("focus", () {
    testWidgets("dims the screen from the first frame of listening, before any word", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit);
      expect(_dim, findsNothing);

      await live(tester: tester, presentation: _focus);
      expect(_dimOpacity(tester), lessThan(0.1));

      await tester.pump(const Duration(milliseconds: 130));
      final partWay = _dimOpacity(tester);
      expect(partWay, inExclusiveRange(0.1, 1));

      await tester.pump(const Duration(milliseconds: 130));
      expect(_dimOpacity(tester), 1);
    });

    testWidgets("words never move or resize the composer, and a word never rebuilds it", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit);
      await live(tester: tester, presentation: _focus);
      await settle(tester);

      final body = find.byType(PregoVoiceWaveform);
      final rect = tester.getRect(body);
      final waveform = tester.widget(body);

      await live(tester: tester, presentation: _focus, confirmed: _longText, provisional: "and more");
      await settle(tester);

      expect(tester.getRect(body), rect);
      // The same instance means the composer's build never ran for the words.
      expect(identical(tester.widget(body), waveform), isTrue);
    });

    testWidgets("words reach only as far as the composer's own width, under the status bar", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit);
      await live(tester: tester, presentation: _focus, confirmed: _longText);
      await settle(tester);

      final clip = tester.getRect(find.ancestor(of: _paragraph, matching: find.byType(ShaderMask)));
      final composer = tester.getRect(find.byType(ComposerLiveWords));
      expect(clip.left, greaterThanOrEqualTo(composer.left));
      expect(clip.right, lessThanOrEqualTo(composer.right));
      expect(clip.top, greaterThanOrEqualTo(0));
      expect(clip.bottom, lessThan(composer.top));
    });

    testWidgets("the hint is redrawn exactly over the composer's own, and goes at the release", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit);
      await live(tester: tester, presentation: _focus, confirmed: "some words");
      await settle(tester);

      final hints = find.text(_releaseToSend);
      expect(hints, findsNWidgets(2));
      expect(tester.getRect(hints.first), tester.getRect(hints.last));

      AnimatedOpacity overlayHint() => tester.widget(
        find.ancestor(of: find.text(_releaseToSend).last, matching: find.byType(AnimatedOpacity)).first,
      );
      expect(overlayHint().opacity, 1);
      final before = tester.getTopLeft(_paragraph);

      await emit(
        tester: tester,
        state: const VoiceInputState.liveFinishing(
          words: LiveWords(confirmed: "some words", provisional: ""),
          presentation: _focus,
        ),
      );
      await settle(tester);

      expect(tester.widget<AnimatedOpacity>(_hintSlot()).opacity, 0);
      expect(tester.getTopLeft(_paragraph), before);
    });

    testWidgets("touches pass through the layer, and a screen reader never gets the words", (tester) async {
      var chatTaps = 0;
      await tester.pumpWidget(
        _ComposerApp(
          voiceCubit: voiceCubit,
          presentation: ComposerPresentation.touch,
          home: (composer) => Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(onTap: () => chatTaps++, behavior: HitTestBehavior.opaque),
                ),
                Align(alignment: Alignment.bottomCenter, child: composer),
              ],
            ),
          ),
        ),
      );
      await settle(tester);
      await live(tester: tester, presentation: _focus, confirmed: _longText);
      await settle(tester);

      await tester.tapAt(tester.getCenter(_dim));
      await tester.pump();
      expect(chatTaps, 1);
      expect(find.ancestor(of: _words, matching: find.byType(ExcludeSemantics)), findsWidgets);
    });

    testWidgets("reads larger on a pointer shell", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit);
      await live(tester: tester, presentation: _focus, confirmed: "words");
      expect(tester.widget<LiveWordsText>(_words).style.fontSize, 23);

      await _pumpComposer(tester: tester, voiceCubit: voiceCubit, presentation: ComposerPresentation.pointer);
      await live(tester: tester, presentation: _focus, confirmed: "words");
      expect(tester.widget<LiveWordsText>(_words).style.fontSize, 25);
    });

    testWidgets("dims only the pane, clear of the composer's column down to the bottom", (tester) async {
      await tester.pumpWidget(
        _ComposerApp(
          voiceCubit: voiceCubit,
          presentation: ComposerPresentation.pointer,
          home: (composer) => Scaffold(
            body: Row(
              children: [
                const SizedBox(width: 200),
                Expanded(
                  child: Scaffold(
                    backgroundColor: const Color(0xFF123456),
                    body: Center(
                      child: SizedBox(
                        width: 400,
                        child: Align(alignment: Alignment.bottomCenter, child: composer),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await settle(tester);
      await live(tester: tester, presentation: _focus);
      await settle(tester);

      expect(tester.getTopLeft(_dim).dx, 200);
      expect(tester.getSize(_dim), const Size(600, 600));

      final body = tester.getRect(find.byType(ComposerLiveWords)).shift(const Offset(-200, 0));
      final painter = tester.renderObject(find.descendant(of: _dim, matching: find.byType(CustomPaint)));
      expect(
        painter,
        paints..path(
          // The gutters beside the composer and the chat above it dim; the
          // composer and the strip below it stay clear.
          includes: [Offset(body.left - 10, body.center.dy), Offset(body.center.dx, body.top - 10)],
          excludes: [body.center, Offset(body.center.dx, 599)],
          color: const Color(0xFF123456),
        ),
      );
    });
  });

  group("words", () {
    testWidgets("tentative words fade in dim, then brighten in place", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit);
      await live(tester: tester, presentation: _focus, provisional: "maybe");
      await settle(tester);
      final top = _paragraphTop(tester);
      expect(_alphaOf(tester, word: "maybe"), closeTo(0.46, 0.01));

      await live(tester: tester, presentation: _focus, confirmed: "maybe");
      await tester.pump(const Duration(milliseconds: 140));
      expect(_alphaOf(tester, word: "maybe"), inExclusiveRange(0.46, 1));
      await tester.pump(const Duration(milliseconds: 150));
      expect(_alphaOf(tester, word: "maybe"), 1);
      expect(_paragraphTop(tester), top);
    });

    testWidgets("a new word fades up to its standing over 170 ms, and leaves earlier ones alone", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit);
      await live(tester: tester, presentation: _focus, confirmed: "first");
      await settle(tester);

      await live(tester: tester, presentation: _focus, confirmed: "first ", provisional: "second");
      await tester.pump(const Duration(milliseconds: 60));
      expect(_alphaOf(tester, word: "second"), inExclusiveRange(0, 0.46));
      expect(_alphaOf(tester, word: "first"), 1);

      await tester.pump(const Duration(milliseconds: 120));
      expect(_alphaOf(tester, word: "second"), closeTo(0.46, 0.01));
    });

    testWidgets("a word the server changes keeps its place and its brightness", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit);
      await live(tester: tester, presentation: _focus, provisional: "there");
      await settle(tester);

      await live(tester: tester, presentation: _focus, provisional: "their");
      // No fade from nothing: at once the new word is as bright as the old one.
      expect(_alphaOf(tester, word: "their"), closeTo(0.46, 0.01));
    });

    testWidgets("the release brightens what was still tentative", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit);
      await live(tester: tester, presentation: _focus, confirmed: "said ", provisional: "maybe");
      await settle(tester);
      expect(_alphaOf(tester, word: "maybe"), closeTo(0.46, 0.01));

      await emit(
        tester: tester,
        state: const VoiceInputState.liveFinishing(
          words: LiveWords(confirmed: "said ", provisional: "maybe"),
          presentation: _focus,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(_alphaOf(tester, word: "maybe"), 1);
    });

    testWidgets("a wrap rises the words smoothly, and the newest line ends up at the bottom", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit);
      const lines = "word word word word word word word word word word word word word word word word word word";
      await live(tester: tester, presentation: _focus, confirmed: lines);
      await settle(tester);

      final style = tester.widget<LiveWordsText>(_words).style;
      final lineHeight = (style.fontSize ?? 0) * (style.height ?? 0);
      final top = _paragraphTop(tester).dy;
      final bottom = tester.getBottomLeft(_paragraph).dy;
      final clipBottom = tester.getBottomLeft(find.ancestor(of: _paragraph, matching: find.byType(ShaderMask))).dy;
      expect(bottom, clipBottom);

      // Enough words for one more line.
      await live(tester: tester, presentation: _focus, confirmed: "$lines $lines");
      final lineCount = (tester.getSize(_paragraph).height / lineHeight).round();
      final growth = tester.getSize(_paragraph).height - (bottom - top);
      expect(lineCount, greaterThan(1));
      expect(growth, greaterThan(0));

      // A frame later they have barely begun to rise rather than snapped.
      await tester.pump(const Duration(milliseconds: 16));
      final oneFrame = top - _paragraphTop(tester).dy;
      expect(oneFrame, inExclusiveRange(0, growth));
      expect(oneFrame, lessThan(growth * 0.5));

      await tester.pump(const Duration(milliseconds: 200));
      expect(top - _paragraphTop(tester).dy, moreOrLessEquals(growth, epsilon: 0.01));
      expect(tester.getBottomLeft(_paragraph).dy, clipBottom);
    });

    testWidgets("words too long for the room keep the newest at the bottom, the oldest cut off", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit);
      await live(tester: tester, presentation: _focus, confirmed: _longText);
      await settle(tester);

      final clip = tester.getRect(find.ancestor(of: _paragraph, matching: find.byType(ShaderMask)));
      expect(tester.getSize(_paragraph).height, greaterThan(_screen.height));
      expect(tester.getBottomLeft(_paragraph).dy, clip.bottom);
      expect(tester.getTopLeft(_paragraph).dy, lessThan(clip.top));
    });

    testWidgets("reduced motion shows words at once and rises nothing", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit, disableAnimations: true);
      await live(tester: tester, presentation: _focus, confirmed: "said ", provisional: "maybe");
      expect(_alphaOf(tester, word: "said"), 1);
      expect(_alphaOf(tester, word: "maybe"), closeTo(0.46, 0.01));

      final clip = find.ancestor(of: _paragraph, matching: find.byType(ShaderMask));
      await live(tester: tester, presentation: _focus, confirmed: _longText);
      await tester.pump();
      expect(tester.getBottomLeft(_paragraph).dy, tester.getBottomLeft(clip).dy);

      // Words leave without travelling.
      await settle(tester);
      await emit(tester: tester, state: const VoiceInputState.cancelling());
      await tester.pump(const Duration(milliseconds: 120));
      expect(_wordsPresence(tester), inExclusiveRange(0, 1));
      expect(_wordsTravel(tester), 0);
    });
  });

  group("panel", () {
    testWidgets("opens with the first word, rising, and never dims", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit);
      await live(tester: tester, presentation: _panel);
      await settle(tester);
      expect(_words, findsNothing);
      expect(_dim, findsNothing);

      await live(tester: tester, presentation: _panel, provisional: "first");
      expect(_dim, findsNothing);
      expect(_wordsTravel(tester), greaterThan(4));
      expect(_wordsPresence(tester), lessThan(0.2));

      await settle(tester);
      expect(_wordsTravel(tester), 0);
      expect(_wordsPresence(tester), 1);
    });

    testWidgets("grows to five lines, then holds its height as older lines scroll away", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit);
      await live(tester: tester, presentation: _panel, confirmed: "one line");
      await settle(tester);
      final clip = find.ancestor(of: _paragraph, matching: find.byType(ShaderMask));
      final style = tester.widget<LiveWordsText>(_words).style;
      final oneLine = tester.getSize(clip).height;
      expect(oneLine, moreOrLessEquals((style.fontSize ?? 0) * (style.height ?? 0), epsilon: 1));

      await live(tester: tester, presentation: _panel, confirmed: _longText);
      await settle(tester);
      expect(tester.getSize(clip).height, moreOrLessEquals(oneLine * 5, epsilon: 1));
      expect(tester.getBottomLeft(_paragraph).dy, tester.getBottomLeft(clip).dy);
      expect(tester.getTopLeft(_paragraph).dy, lessThan(tester.getTopLeft(clip).dy));
    });

    testWidgets("leaves the composer's own hint showing and reserves its room", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit);
      await live(tester: tester, presentation: _panel, confirmed: "words");
      await settle(tester);

      final hints = find.text(_releaseToSend);
      expect(hints, findsNWidgets(2));
      expect(tester.widget<AnimatedOpacity>(_hintSlot()).opacity, 0);
      expect(tester.getBottomLeft(find.byType(LiveWordsText)).dy, lessThan(tester.getTopLeft(hints.first).dy));
    });
  });

  group("slide-out", () {
    /// A real hold, under the layer, with its words up.
    Future<TestGesture> hold({required WidgetTester tester}) async {
      when(voiceCubit.startRecording).thenAnswer((_) async {
        voiceStates.add(const VoiceInputState.liveRecording(words: LiveWords.none, presentation: _focus));
        await Future<void>.delayed(Duration.zero);
      });
      final gesture = await tester.startGesture(tester.getCenter(find.textContaining("Hold to talk")));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await live(tester: tester, presentation: _focus, confirmed: "words");
      await settle(tester);
      return gesture;
    }

    /// [by] above the pill's top edge, where the cancel's arm starts counting.
    Offset abovePill({required WidgetTester tester, required double by}) {
      final pencil = tester.getTopLeft(find.byType(PregoVoiceTarget));
      return Offset(tester.getCenter(find.byType(PregoVoiceWaveform)).dx, pencil.dy - PregoSpacing.sm - by);
    }

    testWidgets("a gesture under the layer still reaches the pill, and the words fade with it", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit);
      final gesture = await hold(tester: tester);
      expect(_scrub(tester).opacity, 1);

      await gesture.moveTo(abovePill(tester: tester, by: 200));
      await tester.pump();
      expect(_scrub(tester).opacity, closeTo(0.4, 0.001));
      expect(_scrub(tester).duration, Duration.zero);
      expect(find.text("Release to cancel"), findsNWidgets(2));

      await gesture.up();
      await tester.pump();
      verify(voiceCubit.cancel).called(1);
    });

    testWidgets("words stay in place as they fade, and come back when the slide does", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit);
      final gesture = await hold(tester: tester);
      final top = _paragraphTop(tester);
      final start = abovePill(tester: tester, by: -10);

      await gesture.moveTo(abovePill(tester: tester, by: 32));
      await tester.pump();
      // Half way to the 64 px arm line.
      expect(_scrub(tester).opacity, closeTo(0.7, 0.001));
      expect(_paragraphTop(tester), top);

      await gesture.moveTo(start);
      await tester.pump();
      expect(_scrub(tester).opacity, 1);

      await gesture.up();
      await tester.pump();
    });

    testWidgets("a release that finishes restores words the slide had dimmed", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit);
      final gesture = await hold(tester: tester);
      await gesture.moveTo(abovePill(tester: tester, by: 32));
      await tester.pump();
      expect(_scrub(tester).opacity, lessThan(1));

      await gesture.up();
      await emit(
        tester: tester,
        state: const VoiceInputState.liveFinishing(
          words: LiveWords(confirmed: "words", provisional: ""),
          presentation: _focus,
        ),
      );
      expect(_scrub(tester).opacity, 1);
      expect(_scrub(tester).duration, greaterThan(Duration.zero));
    });
  });

  group("leaving", () {
    testWidgets("a cancel drops the words 12 px as they fade, then the layer is gone", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit);
      await live(tester: tester, presentation: _focus, confirmed: "words");
      await settle(tester);

      await emit(tester: tester, state: const VoiceInputState.cancelling());
      await tester.pump(const Duration(milliseconds: 120));
      expect(_wordsTravel(tester), inExclusiveRange(0, 12));
      expect(_wordsPresence(tester), inExclusiveRange(0, 1));
      expect(find.text("words", findRichText: true), findsOneWidget);

      // The idle state that follows at once doesn't turn it into a plain fade.
      await emit(tester: tester, state: const VoiceInputState.idle());
      await tester.pump(const Duration(milliseconds: 40));
      expect(_wordsTravel(tester), greaterThan(0));

      await tester.pump(const Duration(milliseconds: 90));
      expect(_words, findsNothing);
      expect(_dim, findsNothing);
      // Really closed: a portal left open is laid out on every resize, even
      // under a pushed route.
      final portal = find.descendant(of: find.byType(ComposerLiveWords), matching: find.byType(OverlayPortal)).first;
      expect(tester.widget<OverlayPortal>(portal).controller.isShowing, isFalse);
    });

    testWidgets("words with no box or bubble to land in fade where they stand", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit);
      await live(tester: tester, presentation: _focus, confirmed: "words");
      await settle(tester);
      final top = _paragraphTop(tester);
      final glideOpacity = find.descendant(of: find.byKey(composerLiveWordsGlideKey), matching: find.byType(Opacity));
      final glideWords = find.descendant(of: find.byKey(composerLiveWordsGlideKey), matching: find.byType(RichText));

      await emit(
        tester: tester,
        state: const VoiceInputState.completed(
          transcript: "words",
          outcome: VoiceDictationOutcome.finished,
          mode: VoiceDictationMode.live,
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.widget<Opacity>(glideOpacity).opacity, inExclusiveRange(0, 1));
      expect(tester.getTopLeft(glideWords), top);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(composerLiveWordsGlideKey), findsNothing);
    });

    testWidgets("a fallback to recording takes the words away", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit);
      await live(tester: tester, presentation: _focus, confirmed: "words");
      await settle(tester);

      await emit(tester: tester, state: const VoiceInputState.recording());
      await tester.pump(const Duration(milliseconds: 300));
      expect(_words, findsNothing);
      expect(_dim, findsNothing);
    });

    testWidgets("words stay put while the composer's body grows under them", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit);
      await live(tester: tester, presentation: _focus, confirmed: "words");
      await settle(tester);
      final top = _paragraphTop(tester);

      final body = tester.state<_ComposerHostState>(find.byType(_ComposerHost));
      await emit(tester: tester, state: const VoiceInputState.idle());
      body.grow();
      await tester.pump();
      await tester.pump();

      expect(_paragraphTop(tester), top);
    });

    testWidgets("a wordless panel ending after an earlier card's fade leaves no layer behind", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit);
      await live(tester: tester, presentation: _panel, confirmed: "words");
      await settle(tester);
      await emit(tester: tester, state: const VoiceInputState.idle());
      await tester.pump(const Duration(milliseconds: 50));

      await live(tester: tester, presentation: _panel);
      await settle(tester);
      await emit(tester: tester, state: const VoiceInputState.idle());
      await settle(tester);

      expect(_words, findsNothing);
    });

    testWidgets("a composer mounting mid-dictation shows the words", (tester) async {
      whenListen(
        voiceCubit,
        voiceStates.stream,
        initialState: const VoiceInputState.liveRecording(
          words: LiveWords(confirmed: "words", provisional: ""),
          presentation: _focus,
        ),
      );
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit);
      await settle(tester);

      expect(_words, findsOneWidget);
      expect(_dimOpacity(tester), 1);
    });

    testWidgets("a composer without voice has no layer", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit, voiceSupport: ComposerVoiceSupport.unsupported);
      expect(find.byType(ComposerLiveWords), findsNothing);
    });
  });
}

/// The slot in the words' column that holds the hint.
Finder _hintSlot() => find
    .descendant(
      of: find.ancestor(of: _words, matching: find.byType(Column)).first,
      matching: find.byType(AnimatedOpacity),
    )
    .last;

Future<void> _pumpComposer({
  required WidgetTester tester,
  required VoiceInputCubit voiceCubit,
  ComposerPresentation presentation = ComposerPresentation.touch,
  ComposerVoiceSupport voiceSupport = ComposerVoiceSupport.supported,
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    _ComposerApp(
      // A new presentation is a new shell, not an update to this one.
      key: ValueKey(presentation),
      voiceCubit: voiceCubit,
      presentation: presentation,
      voiceSupport: voiceSupport,
      disableAnimations: disableAnimations,
      home: (composer) => Scaffold(
        body: Align(alignment: Alignment.bottomCenter, child: composer),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

class const _ComposerApp({
  super.key,
  required final VoiceInputCubit voiceCubit,
  required final ComposerPresentation presentation,
  final ComposerVoiceSupport voiceSupport = ComposerVoiceSupport.supported,
  final bool disableAnimations = false,
  required final Widget Function(Widget composer) home,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
        child: SentBubbleLanding(child: child ?? const SizedBox.shrink()),
      ),
      home: BlocProvider<VoiceInputCubit>.value(
        value: voiceCubit,
        child: ComposerPresentationScope(
          voiceSupport: voiceSupport,
          inputMode: ChatInputMode.voiceFirst,
          isKeyboardVisible: false,
          sendKeyPolicy: ComposerSendKeyPolicy.enterSends,
          presentation: presentation,
          attachmentDispatcher: () => ComposerAttachmentDispatcher(imagePicker: _NoOpComposerImagePicker()),
          imageClipboard: _NoOpImageClipboard.new,
          child: home(const _ComposerHost()),
        ),
      ),
    );
  }
}

/// The composer, with a way to make the room around it change.
class const _ComposerHost() extends StatefulWidget {
  @override
  State<_ComposerHost> createState() => _ComposerHostState();
}

class _ComposerHostState() extends State<_ComposerHost> {
  final _surfaceStyle = ValueNotifier(PregoComposerSurfaceStyle.emphasized);
  double _below = 0;

  /// Moves the composer up, as a body growing under the words would.
  void grow() => setState(() => _below = 80);

  @override
  void dispose() {
    _surfaceStyle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: _below),
      child: PromptInput(
        initialSelection: null,
        onBusyChanged: null,
        onSelectionChanged: null,
        isBusy: false,
        hasMessages: true,
        canSend: true,
        onSend: ({required draft, required command, required attachments}) {},
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
        draftIdentity: "live-words-test",
        restorationKey: null,
        initialDraft: ComposerDraft.typed(text: ""),
        initialAttachments: const [],
        onAttachmentsChanged: null,
        autofocus: false,
        onInitialAttachmentsConsumed: () {},
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
