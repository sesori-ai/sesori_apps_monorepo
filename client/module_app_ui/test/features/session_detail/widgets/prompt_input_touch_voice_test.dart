import "dart:async";
import "dart:math";

import "package:bloc_test/bloc_test.dart";
import "package:flutter/gestures.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/sent_bubble_landing.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

class _MockVoiceInputCubit() extends MockCubit<VoiceInputState> implements VoiceInputCubit;

/// What one composer did, for the endings to assert on.
class _Composer() {
  final List<({String text, String? command})> sent = [];
  final List<AnalyticsVoiceFinish> finishes = [];
  final List<AnalyticsVoiceMode> modes = [];
  int commandsCleared = 0;
  int aborts = 0;
}

/// How a hold ends: a plain release, or a slide up out of the pill first.
enum _HoldEnding() {
  send,
  cancel,
}

/// Past this, two things fading in one place both read at once.
const _visibleOverlap = 0.1;

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
    VoiceDictationMode mode = VoiceDictationMode.afterRecording,
  }) async {
    await emitVoice(
      tester: tester,
      state: VoiceInputState.completed(transcript: transcript, outcome: outcome, mode: mode),
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

      testWidgets("the hint centres over the composer while a trailing control fades in place", (tester) async {
        final trailingFocus = FocusNode();
        addTearDown(trailingFocus.dispose);
        final trailing = Focus(
          focusNode: trailingFocus,
          child: const SizedBox(key: Key("trailing"), width: 90, height: 36),
        );
        await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: mode, composerTrailing: trailing);
        final trailingFinder = find.byKey(const Key("trailing"));
        final restingLeft = tester.getTopLeft(trailingFinder).dx;
        double trailingOpacity() => tester
            .widget<AnimatedOpacity>(find.ancestor(of: trailingFinder, matching: find.byType(AnimatedOpacity)).first)
            .opacity;

        final gesture = await hold(tester: tester, mode: mode);
        await tester.pump(const Duration(milliseconds: 300));
        final hint = find.text("Release to send · slide up to cancel");
        expect(tester.getCenter(hint).dx, closeTo(tester.getCenter(find.byType(PromptInput)).dx, 0.5));
        expect(trailingOpacity(), 0);
        expect(trailingFocus.canRequestFocus, isFalse, reason: "Tab must not land on a control nobody can see.");
        expect(
          tester.widget<AnimatedSize>(find.ancestor(of: hint, matching: find.byType(AnimatedSize)).first).clipBehavior,
          Clip.none,
          reason: "The hint reaches past the slot, so a slot growing for large text must not cut it off.",
        );
        expect(tester.getTopLeft(trailingFinder).dx, restingLeft, reason: "Nothing in the row moves.");

        await gesture.up();
        await tester.pump();
        await complete(tester: tester, transcript: "spoken words", outcome: VoiceDictationOutcome.finished);
        await tester.pump(const Duration(milliseconds: 300));
        expect(trailingOpacity(), 1);
        expect(trailingFocus.canRequestFocus, isTrue);
      });

      testWidgets("at large text a taller hint leaves the fading header where it sits", (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _pumpComposer(
          tester: tester,
          voiceCubit: voiceCubit,
          mode: mode,
          composerHeader: const SizedBox(key: Key("model row"), height: 44),
        );
        final header = find.byKey(const Key("model row"));
        final hint = find.textContaining("Release");
        final restingTop = tester.getTopLeft(header).dy;

        final gesture = await tester.startGesture(tester.getCenter(_holdTarget(mode: mode)));
        await tester.pump();
        for (var i = 0; i < 16; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          for (var copy = 0; copy < header.evaluate().length; copy++) {
            expect(tester.getTopLeft(header.at(copy)).dy, restingTop, reason: "moved holding, frame $i");
          }
        }
        await tester.pump(const Duration(milliseconds: 300));
        expect(hint, findsOneWidget);

        await gesture.up();
        await tester.pump();
        for (var i = 0; i < 16; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          for (var copy = 0; copy < header.evaluate().length; copy++) {
            expect(tester.getTopLeft(header.at(copy)).dy, restingTop, reason: "moved releasing, frame $i");
          }
        }
        await complete(tester: tester, transcript: "spoken words", outcome: VoiceDictationOutcome.finished);
      });

      testWidgets("a quick tap turns every fade back from where it had reached", (tester) async {
        await _pumpComposer(
          tester: tester,
          voiceCubit: voiceCubit,
          mode: mode,
          composerHeader: const SizedBox(key: Key("model row"), height: 44),
          composerTrailing: const SizedBox(key: Key("trailing"), width: 90, height: 36),
        );
        final watched = <String, Finder>{
          "header": find.byKey(const Key("model row")),
          "trailing": find.byKey(const Key("trailing")),
          "accordion": find.byIcon(TablerRegular.chevron_right),
          "idle slot": switch (mode) {
            ChatInputMode.voiceFirst => find.textContaining("Hold to talk"),
            ChatInputMode.textFirst => find.text("Follow up..."),
          },
          if (mode == ChatInputMode.voiceFirst) "keyboard": find.byIcon(TablerRegular.keyboard),
        };
        final previous = {for (final MapEntry(:key, :value) in watched.entries) key: _shownOpacity(value)};
        void expectNoSnap({required String frame}) {
          for (final MapEntry(:key, :value) in watched.entries) {
            final shown = _shownOpacity(value);
            // The steepest honest step is the house ease leaving its start.
            expect((shown - (previous[key] ?? 0)).abs(), lessThan(0.3), reason: "$key snapped at $frame");
            previous[key] = shown;
          }
        }

        final gesture = await tester.startGesture(tester.getCenter(_holdTarget(mode: mode)));
        await tester.pump();
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expectNoSnap(frame: "down+$i");
        }
        await gesture.up();
        await tester.pump();
        expectNoSnap(frame: "release");
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expectNoSnap(frame: "up+$i");
        }
        await tester.pump(const Duration(milliseconds: 300));
        for (final MapEntry(:key, :value) in watched.entries) {
          expect(_shownOpacity(value), 1, reason: "$key must come back");
        }
      });

      testWidgets("pressing again and again mid-fade holds together", (tester) async {
        await _pumpComposer(
          tester: tester,
          voiceCubit: voiceCubit,
          mode: mode,
          composerHeader: const SizedBox(key: Key("model row"), height: 44),
        );
        final target = tester.getCenter(_holdTarget(mode: mode));
        for (var press = 0; press < 3; press++) {
          final gesture = await tester.startGesture(target);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 60));
          await gesture.up();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 40));
        }
        verify(voiceCubit.startRecording).called(3);
        await tester.pump(const Duration(milliseconds: 500));
        expect(_shownOpacity(find.byKey(const Key("model row"))), 1);
      });

      for (final ending in _HoldEnding.values) {
        for (final frameMs in [8, 16]) {
          testWidgets("a press dissolves and a release clears the hint first, ${ending.name}, $frameMs ms frames", (
            tester,
          ) async {
            await _pumpComposer(
              tester: tester,
              voiceCubit: voiceCubit,
              mode: mode,
              composerHeader: const SizedBox(key: Key("model row"), height: 44),
            );
            final header = find.byKey(const Key("model row"));
            final hint = find.textContaining("Release to");
            final dots = find.byType(PregoVoiceWaveform);
            final resting = _restingWords(mode: mode);

            final gesture = await tester.startGesture(tester.getCenter(_holdTarget(mode: mode)));
            await tester.pump();
            for (var elapsed = frameMs; elapsed <= 220; elapsed += frameMs) {
              await tester.pump(Duration(milliseconds: frameMs));
              final arrived = elapsed / 220;
              expect(_shownOpacity(hint), closeTo(arrived, 0.01), reason: "hint at $elapsed ms");
              expect(_shownOpacity(dots), closeTo(arrived, 0.01), reason: "dots at $elapsed ms");
              expect(_shownOpacity(header), closeTo(1 - arrived, 0.01), reason: "header at $elapsed ms");
              expect(_shownOpacity(resting), closeTo(1 - arrived, 0.01), reason: "resting words at $elapsed ms");
            }
            await tester.pump(const Duration(milliseconds: 100));

            if (ending == _HoldEnding.cancel) {
              await gesture.moveTo(abovePill(tester: tester, by: 64));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 300));
            }
            await gesture.up();
            await tester.pump();
            final incoming = switch (ending) {
              _HoldEnding.send => find.byType(PregoShimmer),
              _HoldEnding.cancel => resting,
            };
            for (var elapsed = frameMs; elapsed <= 240; elapsed += frameMs) {
              await tester.pump(Duration(milliseconds: frameMs));
              final overHeader = min(_shownOpacity(hint), _shownOpacity(header));
              expect(overHeader, lessThan(_visibleOverlap), reason: "hint over the header at $elapsed ms");
              final overDots = min(_shownOpacity(dots), _shownOpacity(incoming));
              expect(overDots, lessThan(_visibleOverlap), reason: "words over the dots at $elapsed ms");
            }
            expect(_shownOpacity(header), 1);
            expect(_shownOpacity(incoming), 1);
            expect(hint, findsNothing);

            if (ending == _HoldEnding.send) {
              await complete(tester: tester, transcript: "spoken words", outcome: VoiceDictationOutcome.finished);
            }
          });
        }
      }

      for (final tapMs in [64, 112, 160, 208]) {
        testWidgets("a $tapMs ms tap dissolves back without blinking empty", (tester) async {
          await _pumpComposer(
            tester: tester,
            voiceCubit: voiceCubit,
            mode: mode,
            composerHeader: const SizedBox(key: Key("model row"), height: 44),
          );
          final watched = [find.byKey(const Key("model row")), find.textContaining("Release to")];
          final gesture = await tester.startGesture(tester.getCenter(_holdTarget(mode: mode)));
          await tester.pump();
          await tester.pump(Duration(milliseconds: tapMs));
          await gesture.up();
          var previous = watched.map(_shownOpacity).toList();
          for (var i = 0; i < 25; i++) {
            await tester.pump(i == 0 ? Duration.zero : const Duration(milliseconds: 16));
            final shown = watched.map(_shownOpacity).toList();
            expect(shown.reduce(max), greaterThan(0.3), reason: "empty at frame $i");
            for (var w = 0; w < watched.length; w++) {
              expect((shown[w] - previous[w]).abs(), lessThan(0.1), reason: "${watched[w]} jumped at frame $i");
            }
            previous = shown;
          }
          expect(previous.first, tapMs < 200 ? 1 : closeTo(1, 0.01));
        });
      }

      for (final pressAgainMs in [48, 96, 160, 200]) {
        testWidgets("pressing again $pressAgainMs ms into a release carries on from where it was", (tester) async {
          await _pumpComposer(
            tester: tester,
            voiceCubit: voiceCubit,
            mode: mode,
            composerHeader: const SizedBox(key: Key("model row"), height: 44),
          );
          final header = find.byKey(const Key("model row"));
          final hint = find.textContaining("Release to");
          final dots = find.byType(PregoVoiceWaveform);
          final target = tester.getCenter(_holdTarget(mode: mode));

          Future<void> slideOffAndLift(TestGesture gesture) async {
            await gesture.moveTo(abovePill(tester: tester, by: 64));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            await gesture.up();
            await tester.pump();
          }

          await slideOffAndLift(await hold(tester: tester, mode: mode));
          await tester.pump(Duration(milliseconds: pressAgainMs));
          var previous = [_shownOpacity(header), _shownOpacity(hint), _shownOpacity(dots)];
          final again = await tester.startGesture(target);
          await tester.pump();
          for (var i = 0; i < 24; i++) {
            await tester.pump(const Duration(milliseconds: 16));
            final shown = [_shownOpacity(header), _shownOpacity(hint), _shownOpacity(dots)];
            // The header retraces its way in, whose steepest honest step is that ease leaving its start.
            expect((shown[0] - previous[0]).abs(), lessThan(0.5), reason: "header snapped at frame $i");
            expect((shown[1] - previous[1]).abs(), lessThan(0.1), reason: "hint snapped at frame $i");
            expect((shown[2] - previous[2]).abs(), lessThan(0.1), reason: "dots snapped at frame $i");
            previous = shown;
          }
          expect(previous, [0, 1, 1]);
          await slideOffAndLift(again);
          await tester.pump(const Duration(milliseconds: 300));
          expect(_shownOpacity(header), 1);
        });
      }

      testWidgets("reduced motion swaps the hint and what it covers at once", (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
          disableAnimations: true,
        );
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        await _pumpComposer(
          tester: tester,
          voiceCubit: voiceCubit,
          mode: mode,
          composerHeader: const SizedBox(key: Key("model row"), height: 44),
        );
        final header = find.byKey(const Key("model row"));
        final hint = find.textContaining("Release to");
        final dots = find.byType(PregoVoiceWaveform);
        final resting = _restingWords(mode: mode);

        final gesture = await tester.startGesture(tester.getCenter(_holdTarget(mode: mode)));
        await tester.pump();
        expect(_shownOpacity(hint), 1);
        expect(header, findsNothing);
        await tester.pump(const Duration(milliseconds: 16));
        expect(_shownOpacity(dots), 1);
        expect(resting, findsNothing);

        await tester.pump(const Duration(milliseconds: 300));
        await gesture.moveTo(abovePill(tester: tester, by: 64));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await gesture.up();
        await tester.pump();
        expect(_shownOpacity(header), 1);
        expect(hint, findsNothing);
        await tester.pump(const Duration(milliseconds: 16));
        expect(_shownOpacity(resting), 1);
        expect(dots, findsNothing);
      });

      testWidgets("at large text the composer still eases open and closed around a release", (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _pumpComposer(
          tester: tester,
          voiceCubit: voiceCubit,
          mode: mode,
          composerHeader: const SizedBox(key: Key("model row"), height: 28),
        );
        final composer = find.byType(PromptInput);
        final resting = tester.getSize(composer).height;

        final gesture = await tester.startGesture(tester.getCenter(_holdTarget(mode: mode)));
        await tester.pump();
        final growth = <double>{};
        for (var i = 0; i < 16; i++) {
          final before = tester.getSize(composer).height;
          await tester.pump(const Duration(milliseconds: 16));
          final after = tester.getSize(composer).height;
          expect(after - before, inInclusiveRange(0, 6), reason: "jumped growing at frame $i");
          growth.add(after);
        }
        expect(growth.length, greaterThan(5), reason: "the growth eases over many frames");
        final open = tester.getSize(composer).height;
        expect(open, greaterThan(resting));

        await gesture.up();
        await tester.pump();
        for (var i = 0; i < 40; i++) {
          final before = tester.getSize(composer).height;
          await tester.pump(const Duration(milliseconds: 16));
          expect(before - tester.getSize(composer).height, inInclusiveRange(0, 6), reason: "jumped closing at $i");
        }
        expect(tester.getSize(composer).height, resting);
        await complete(tester: tester, transcript: "spoken words", outcome: VoiceDictationOutcome.finished);
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

      group("live", () {
        const cutOffNotice = "Dictation was cut off. Check your words before sending.";

        setUp(() {
          when(voiceCubit.startRecording).thenAnswer((_) async {
            voiceStates.add(const VoiceInputState.liveRecording(words: LiveWords.none));
            await Future<void>.delayed(Duration.zero);
          });
          when(() => voiceCubit.stopAndTranscribe(limitReached: false)).thenAnswer((_) async {
            voiceStates.add(const VoiceInputState.liveFinishing(words: LiveWords.none));
          });
        });

        testWidgets("a release finishes, says so, and sends the words with no notice", (tester) async {
          final composer = await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: mode);

          final gesture = await hold(tester: tester, mode: mode);
          expect(find.text("Release to send · slide up to cancel"), findsOneWidget);

          await gesture.up();
          await tester.pump();
          await tester.pump();
          verify(() => voiceCubit.stopAndTranscribe(limitReached: false)).called(1);
          expect(find.text("Finishing..."), findsOneWidget);

          await complete(
            tester: tester,
            transcript: "live words",
            outcome: VoiceDictationOutcome.finished,
            mode: VoiceDictationMode.live,
          );

          expect(composer.sent, [(text: "live words", command: null)]);
          expect(composer.finishes, [AnalyticsVoiceFinish.sent]);
          expect(composer.modes, [AnalyticsVoiceMode.live]);
          expect(find.text(cutOffNotice), findsNothing);
          expect(find.text("Dictation limit reached"), findsNothing);
        });

        testWidgets("cut off after the release lands in the box with a notice, never sent (D20)", (tester) async {
          final composer = await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: mode);

          final gesture = await hold(tester: tester, mode: mode);
          await gesture.up();
          await tester.pump();
          await complete(
            tester: tester,
            transcript: "cut off words",
            outcome: VoiceDictationOutcome.interrupted,
            mode: VoiceDictationMode.live,
          );

          expect(composer.sent, isEmpty);
          expect(composer.finishes, [AnalyticsVoiceFinish.cutOff]);
          expect(composer.modes, [AnalyticsVoiceMode.live]);
          expect(find.text("cut off words"), findsOneWidget);
          expect(find.text(cutOffNotice), findsOneWidget);
        });

        testWidgets("cut off with the finger down lands in the box and the release sends nothing", (tester) async {
          final composer = await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: mode);

          final gesture = await hold(tester: tester, mode: mode);
          await complete(
            tester: tester,
            transcript: "cut off words",
            outcome: VoiceDictationOutcome.interrupted,
            mode: VoiceDictationMode.live,
          );
          await gesture.up();
          await tester.pump();

          expect(composer.sent, isEmpty);
          expect(find.text("cut off words"), findsOneWidget);
          expect(find.text(cutOffNotice), findsOneWidget);
        });

        testWidgets("a fallback's recording lands in the box with the same notice, never sent (D33)", (tester) async {
          final composer = await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: mode);

          final gesture = await hold(tester: tester, mode: mode);
          await emitVoice(tester: tester, state: const VoiceInputState.recording());
          await gesture.up();
          await tester.pump();
          await emitVoice(tester: tester, state: const VoiceInputState.transcribing(limitReached: false));
          await complete(
            tester: tester,
            transcript: "recorded words",
            outcome: VoiceDictationOutcome.interrupted,
            mode: VoiceDictationMode.afterRecording,
          );

          expect(composer.sent, isEmpty);
          expect(composer.modes, [AnalyticsVoiceMode.afterRecording]);
          expect(find.text("recorded words"), findsOneWidget);
          expect(find.text(cutOffNotice), findsOneWidget);
        });

        testWidgets("the server's limit lands in the box with its own notice", (tester) async {
          final composer = await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: mode);

          final gesture = await hold(tester: tester, mode: mode);
          await complete(
            tester: tester,
            transcript: "limited words",
            outcome: VoiceDictationOutcome.limitReached,
            mode: VoiceDictationMode.live,
          );
          await gesture.up();
          await tester.pump();

          expect(composer.sent, isEmpty);
          expect(composer.finishes, [AnalyticsVoiceFinish.cutOff]);
          expect(find.text("limited words"), findsOneWidget);
          expect(find.text("Dictation limit reached"), findsOneWidget);
        });

        testWidgets("a network failure offers no retry and sends nothing", (tester) async {
          final composer = await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: mode);

          final gesture = await hold(tester: tester, mode: mode);
          await gesture.up();
          await tester.pump();
          await emitVoice(
            tester: tester,
            state: VoiceInputState.transcriptionFailed(error: VoiceTranscriptionError.networkError(innerError: null)),
          );

          expect(composer.sent, isEmpty);
          expect(find.text("Transcription failed. Record again or type instead."), findsOneWidget);
          expect(find.text("Retry"), findsNothing);
          verifyNever(voiceCubit.retry);
        });
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

  for (final isBusy in [false, true]) {
    testWidgets("the hold to talk label and shimmer fade where they stand, busy: $isBusy", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: ChatInputMode.voiceFirst, isBusy: isBusy);
      final label = find.textContaining("Hold to talk");
      final shimmer = find.byType(PregoShimmer);
      final restingCentre = tester.getCenter(label).dx;
      // Centred between the actions, with or without the stop button beside the
      // keyboard one: the distance from each button's centre to the gap is equal.
      final firstAction = tester.getCenter(find.byIcon(TablerRegular.chevron_right)).dx;
      final lastAction = tester.getCenter(find.byIcon(TablerRegular.keyboard)).dx;
      expect(restingCentre, closeTo((firstAction + lastAction) / 2, 0.5));

      void expectInPlace({required Finder finder, required String frame}) {
        for (var i = 0; i < finder.evaluate().length; i++) {
          expect(tester.getCenter(finder.at(i)).dx, closeTo(restingCentre, 0.01), reason: "moved at $frame");
        }
      }

      final gesture = await tester.startGesture(tester.getCenter(label));
      await tester.pump();
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expectInPlace(finder: label, frame: "fading out, $i");
      }
      await tester.pump(const Duration(milliseconds: 300));
      expect(label, findsNothing);

      await gesture.up();
      await tester.pump();
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(shimmer, findsOneWidget);
        expectInPlace(finder: shimmer, frame: "transcribing, $i");
      }
      await complete(tester: tester, transcript: "spoken words", outcome: VoiceDictationOutcome.finished);
      expect(tester.getCenter(label).dx, restingCentre);
    });
  }

  testWidgets("text-first's hint stays in its tappable slot on touch", (tester) async {
    await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: ChatInputMode.textFirst);

    final hint = find.text("Follow up...");
    final ignoring = tester
        .widgetList<IgnorePointer>(find.ancestor(of: hint, matching: find.byType(IgnorePointer)))
        .where((widget) => widget.ignoring);
    expect(ignoring, isEmpty, reason: "the caption layer ignores touches");
    expect(find.ancestor(of: hint, matching: find.byType(GestureDetector)), findsWidgets);
  });

  group("a screen reader on the composer's icon buttons", () {
    SemanticsNode nodeNamed(String label) => find.semantics.byLabel(label).evaluate().single;
    FinderBase<SemanticsNode> tapNamed(String label) => find.semantics.byPredicate((node) {
      final data = node.getSemanticsData();
      return data.label == label && data.hasAction(SemanticsAction.tap);
    });
    final unnamedTaps = find.semantics.byPredicate((node) {
      final data = node.getSemanticsData();
      return !node.isMergedIntoParent &&
          data.hasAction(SemanticsAction.tap) &&
          data.label.isEmpty &&
          data.tooltip.isEmpty;
    });

    for (final presentation in ComposerPresentation.values) {
      for (final isBusy in [false, true]) {
        testWidgets("voice-first's pill and buttons each say their own words, ${presentation.name}, busy: $isBusy", (
          tester,
        ) async {
          final semantics = tester.ensureSemantics();
          final composer = await _pumpComposer(
            tester: tester,
            voiceCubit: voiceCubit,
            mode: ChatInputMode.voiceFirst,
            isBusy: isBusy,
            presentation: presentation,
            composerHeader: const Text("Header words"),
          );

          expect(
            nodeNamed("Hold to talk"),
            isSemantics(label: "Hold to talk", tooltip: "", isButton: true, hasTapAction: true),
          );
          expect(
            nodeNamed("Type a message"),
            isSemantics(
              label: "Type a message",
              tooltip: "",
              isButton: true,
              isEnabled: true,
              hasTapAction: true,
              hasFocusAction: true,
            ),
          );
          expect(unnamedTaps, findsNothing);
          if (isBusy) {
            expect(nodeNamed("Stop"), isSemantics(label: "Stop", isButton: true, hasTapAction: true));
            tester.semantics.tap(find.semantics.byLabel("Stop"));
            expect(composer.aborts, 1);
          } else {
            expect(find.semantics.byLabel("Stop"), findsNothing);
          }
          semantics.dispose();
        });
      }
    }

    testWidgets("voice-first's pill says what it shows with a draft in the box", (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpComposer(
        tester: tester,
        voiceCubit: voiceCubit,
        mode: ChatInputMode.voiceFirst,
        initialText: "draft words",
      );
      expect(find.text("Hold to talk more"), findsOneWidget);
      expect(nodeNamed("Hold to talk more"), isSemantics(label: "Hold to talk more", isButton: true));
      expect(find.semantics.byLabel("Hold to talk"), findsNothing);
      semantics.dispose();
    });

    testWidgets("a semantic tap on the keyboard button opens typing, not a recording", (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: ChatInputMode.voiceFirst);
      expect(find.byType(EditableText), findsNothing);

      tester.semantics.tap(find.semantics.byLabel("Type a message"));
      await tester.pumpAndSettle();

      expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
      verifyNever(voiceCubit.startRecording);
      semantics.dispose();
    });

    testWidgets("a semantic tap on the pill still toggles recording, and the keyboard button takes none meanwhile", (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: ChatInputMode.voiceFirst);
      expect(tapNamed("Type a message"), findsOne);

      tester.semantics.tap(find.semantics.byLabel("Hold to talk"));
      await tester.pump();
      await tester.pump();
      verify(voiceCubit.startRecording).called(1);
      expect(tapNamed("Type a message"), findsNothing);
      expect(nodeNamed("Hold to talk"), isSemantics(hasTapAction: true, hasDismissAction: true));

      // Past the recording's minimum, which a shorter one is cancelled under.
      await tester.pump(const Duration(seconds: 1));
      tester.semantics.tap(find.semantics.byLabel("Hold to talk"));
      await tester.pump();
      verify(() => voiceCubit.stopAndTranscribe(limitReached: false)).called(1);
      semantics.dispose();
    });

    testWidgets("the keyboard button takes no screen reader tap during a hold", (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: ChatInputMode.voiceFirst);

      final gesture = await tester.startGesture(tester.getCenter(find.textContaining("Hold to talk")));
      await tester.pump();
      expect(tapNamed("Type a message"), findsNothing, reason: "From the hold's first frame.");
      await tester.pump(const Duration(milliseconds: 300));
      expect(tapNamed("Type a message"), findsNothing);

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 500));
      semantics.dispose();
    });

    for (final (name, state, label) in [
      ("transcribing", const VoiceInputState.transcribing(limitReached: false), "Transcribing..."),
      ("finishing", const VoiceInputState.liveFinishing(words: LiveWords.none), "Finishing..."),
    ]) {
      testWidgets("the pill says only that it's $name, and cancelling is named", (tester) async {
        final semantics = tester.ensureSemantics();
        await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: ChatInputMode.voiceFirst);

        final gesture = await hold(tester: tester, mode: ChatInputMode.voiceFirst);
        await gesture.up();
        await tester.pump();
        await emitVoice(tester: tester, state: state);
        await tester.pump(const Duration(milliseconds: 500));

        expect(nodeNamed(label), isSemantics(label: label, tooltip: "", isButton: true, hasTapAction: true));
        expect(unnamedTaps, findsNothing);
        tester.semantics.tap(find.semantics.byLabel("Cancel transcription"));
        await tester.pump();
        verify(voiceCubit.cancel).called(1);
        await tester.pump(const Duration(milliseconds: 500));
        semantics.dispose();
      });
    }

    testWidgets("text-first's send and stop keep their words off the pill", (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: ChatInputMode.textFirst);
      expect(find.semantics.byPredicate((node) => node.getSemanticsData().tooltip == "Send"), findsNothing);
      expect(
        nodeNamed("Send"),
        isSemantics(label: "Send", isButton: true, isEnabled: false, hasEnabledState: true, hasTapAction: false),
      );

      final composer = await _pumpComposer(
        tester: tester,
        voiceCubit: voiceCubit,
        mode: ChatInputMode.textFirst,
        isBusy: true,
      );
      expect(find.semantics.byPredicate((node) => node.getSemanticsData().tooltip == "Stop"), findsNothing);
      tester.semantics.tap(find.semantics.byLabel("Stop"));
      expect(composer.aborts, 1);
      expect(unnamedTaps, findsNothing);
      semantics.dispose();
    });

    testWidgets("a pointer shell's mic is a named button that starts recording", (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpComposer(
        tester: tester,
        voiceCubit: voiceCubit,
        mode: ChatInputMode.textFirst,
        presentation: ComposerPresentation.pointer,
      );

      expect(nodeNamed("Record voice"), isSemantics(label: "Record voice", tooltip: "", isButton: true));
      expect(unnamedTaps, findsNothing);
      tester.semantics.tap(find.semantics.byLabel("Record voice"));
      await tester.pump();
      verify(voiceCubit.startRecording).called(1);
      await tester.pump(const Duration(milliseconds: 500));
      semantics.dispose();
    });

    testWidgets("the keyboard button still shows its tooltip on long-press and hover, and still taps", (tester) async {
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: ChatInputMode.voiceFirst);
      final keyboard = find.byIcon(TablerRegular.keyboard);

      await tester.longPress(keyboard);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text("Type a message"), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text("Type a message"), findsNothing);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(keyboard));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text("Type a message"), findsOneWidget);
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.byType(EditableText), findsNothing);
      await tester.tap(keyboard);
      await tester.pumpAndSettle();
      expect(find.byType(EditableText), findsOneWidget);
    });
  });

  testWidgets("voice-first's pill says it's transcribing to a screen reader", (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: ChatInputMode.voiceFirst, initialText: "");
    expect(find.bySemanticsLabel("Transcribing..."), findsNothing);

    final gesture = await hold(tester: tester, mode: ChatInputMode.voiceFirst);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.bySemanticsLabel("Transcribing..."), findsOneWidget);
    expect(find.bySemanticsLabel("Hold to talk"), findsNothing);

    await emitVoice(tester: tester, state: const VoiceInputState.idle());
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.bySemanticsLabel("Transcribing..."), findsNothing);
    expect(find.bySemanticsLabel("Hold to talk"), findsOneWidget);
    semantics.dispose();
  });

  for (final (layout, initialText) in [("compact", ""), ("typing", "draft words")]) {
    testWidgets("text-first's shimmer fades where it stands, $layout", (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpComposer(
        tester: tester,
        voiceCubit: voiceCubit,
        mode: ChatInputMode.textFirst,
        initialText: initialText,
      );
      // Centred between the actions as they rest, with the send button back.
      final firstAction = tester.getCenter(find.byIcon(TablerRegular.chevron_right)).dx;
      final mic = find.byIcon(TablerRegular.microphone);
      final restingCentre = (firstAction + tester.getCenter(mic).dx) / 2;
      final restingY = tester.getCenter(mic).dy;
      final shimmer = find.text("Transcribing...");

      void expectInPlace({required String frame}) {
        for (var i = 0; i < shimmer.evaluate().length; i++) {
          final centre = tester.getCenter(shimmer.at(i));
          expect(centre.dx, closeTo(restingCentre, 0.01), reason: "moved sideways at $frame");
          expect(centre.dy, closeTo(restingY, 0.5), reason: "left the row at $frame");
        }
      }

      final gesture = await hold(tester: tester, mode: ChatInputMode.textFirst);
      await gesture.up();
      await tester.pump();
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(shimmer, findsOneWidget);
        expectInPlace(frame: "fading in, $i");
      }
      expect(_shownOpacity(shimmer), 1);
      expect(
        find.bySemanticsLabel("Transcribing..."),
        findsOneWidget,
        reason: "text-first has no hold surface to speak",
      );
      semantics.dispose();

      await emitVoice(
        tester: tester,
        state: const VoiceInputState.completed(
          transcript: "spoken words",
          outcome: VoiceDictationOutcome.finished,
          mode: VoiceDictationMode.afterRecording,
        ),
      );
      await emitVoice(tester: tester, state: const VoiceInputState.idle());
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expectInPlace(frame: "fading out, $i");
      }
      await tester.pump(const Duration(milliseconds: 500));
      expect(shimmer, findsNothing);
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

  group("text-first's mic stays under the finger", () {
    final mic = find.byIcon(TablerRegular.microphone);
    final send = find.byIcon(TablerRegular.arrow_up);
    final waveform = find.byType(PregoVoiceWaveform);
    final sendForScreenReader = find.semantics.byLabel("Send");

    void setPhone({required WidgetTester tester, required double width}) {
      tester.view.physicalSize = Size(width * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    for (final (layout, initialText, width, textScale) in [
      ("compact", "", 390.0, 1.0),
      ("typing", "draft words", 390.0, 1.0),
      ("compact, small and large text", "", 320.0, 2.0),
      ("typing, small and large text", "draft words", 320.0, 2.0),
    ]) {
      testWidgets("send fades where it stands, and nothing moves, $layout", (tester) async {
        setPhone(tester: tester, width: width);
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _pumpComposer(
          tester: tester,
          voiceCubit: voiceCubit,
          mode: ChatInputMode.textFirst,
          initialText: initialText,
        );
        final micLeft = tester.getTopLeft(mic).dx;
        final sendLeft = tester.getTopLeft(send).dx;
        final composerCentre = tester.getCenter(find.byType(PromptInput)).dx;

        final gesture = await tester.startGesture(tester.getCenter(mic));
        await tester.pump();
        final waveformRect = tester.getRect(waveform);
        expect(
          waveformRect.right,
          tester.getCenter(mic).dx - 22 - PregoSpacing.md,
          reason: "The waveform ends beside the mic, which never gained the send button's room.",
        );
        for (var ms = 16; ms <= 288; ms += 16) {
          await tester.pump(const Duration(milliseconds: 16));
          final faded = Curves.easeOutCubic.transform((ms / 220).clamp(0.0, 1.0));
          expect(_shownOpacity(send), closeTo(1 - faded, 0.01), reason: "the house fade, holding, $ms ms");
          expect(tester.getTopLeft(mic).dx, micLeft, reason: "mic moved holding, $ms ms");
          expect(tester.getTopLeft(send).dx, sendLeft, reason: "send moved holding, $ms ms");
          final rect = tester.getRect(waveform);
          expect(rect.left, waveformRect.left, reason: "waveform moved holding, $ms ms");
          expect(rect.right, waveformRect.right, reason: "waveform resized holding, $ms ms");
          expect(rect.top, closeTo(waveformRect.top, 0.01), reason: "waveform rose holding, $ms ms");
          expect(
            tester.getCenter(find.text("Release to send · slide up to cancel")).dx,
            closeTo(composerCentre, 0.5),
          );
        }
        expect(_shownOpacity(send), 0);

        await gesture.up();
        await tester.pump();
        for (var ms = 16; ms <= 288; ms += 16) {
          await tester.pump(const Duration(milliseconds: 16));
          final returned = Curves.easeOutCubic.transform((ms / 220).clamp(0.0, 1.0));
          expect(_shownOpacity(send), closeTo(returned, 0.01), reason: "the house fade, releasing, $ms ms");
          expect(tester.getTopLeft(mic).dx, micLeft, reason: "mic moved releasing, $ms ms");
          expect(tester.getTopLeft(send).dx, sendLeft, reason: "send moved releasing, $ms ms");
        }
        expect(_shownOpacity(send), 1);
        await complete(tester: tester, transcript: "spoken words", outcome: VoiceDictationOutcome.finished);
      });
    }

    testWidgets("reduced motion swaps send at once, with the mic still", (tester) async {
      setPhone(tester: tester, width: 390);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: ChatInputMode.textFirst);
      final micLeft = tester.getTopLeft(mic).dx;

      final gesture = await tester.startGesture(tester.getCenter(mic));
      await tester.pump();
      expect(_shownOpacity(send), 0);
      expect(tester.getTopLeft(mic).dx, micLeft);

      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pump();
      await tester.pump();
      expect(_shownOpacity(send), 1);
      expect(tester.getTopLeft(mic).dx, micLeft);
      await complete(tester: tester, transcript: "spoken words", outcome: VoiceDictationOutcome.finished);
    });

    testWidgets("a fading send takes no touch, focus or screen reader tap, then comes back with the text", (
      tester,
    ) async {
      setPhone(tester: tester, width: 390);
      final semantics = tester.ensureSemantics();
      final composer = await _pumpComposer(
        tester: tester,
        voiceCubit: voiceCubit,
        mode: ChatInputMode.textFirst,
        initialText: "draft words",
      );
      final micLeft = tester.getTopLeft(mic).dx;
      bool excludesFocus() => tester
          .widgetList<ExcludeFocus>(find.ancestor(of: send, matching: find.byType(ExcludeFocus)))
          .any((exclude) => exclude.excluding);
      final sendTapForScreenReader = find.semantics.byPredicate((node) {
        final data = node.getSemanticsData();
        return data.label == "Send" && data.hasAction(SemanticsAction.tap);
      });
      expect(sendTapForScreenReader, findsOne);
      expect(excludesFocus(), isFalse);

      final gesture = await tester.startGesture(tester.getCenter(mic));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(_shownOpacity(send), greaterThan(0.5), reason: "Still mostly visible, and already dead.");
      expect(sendTapForScreenReader, findsNothing);
      expect(excludesFocus(), isTrue);
      await tester.tap(send, warnIfMissed: false);

      await tester.pump(const Duration(milliseconds: 300));
      expect(sendForScreenReader, findsNothing, reason: "Nothing to read out once it has gone.");
      await tester.tap(send, warnIfMissed: false);
      await tester.pump();
      expect(composer.sent, isEmpty);

      final waveformRect = tester.getRect(waveform);
      await gesture.moveTo(abovePill(tester: tester, by: 64));
      await tester.pump();
      expect(tester.getTopLeft(mic).dx, micLeft, reason: "The slide up moves nothing.");
      expect(tester.getRect(waveform), waveformRect);

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_shownOpacity(send), 1);
      expect(tester.getTopLeft(mic).dx, micLeft);
      expect(sendTapForScreenReader, findsOne);
      expect(excludesFocus(), isFalse);
      expect(find.text("draft words"), findsOneWidget, reason: "A cancel keeps what the box held.");
      expect(composer.sent, isEmpty);
      semantics.dispose();
    });

    testWidgets("voice-first's send stays and fades, and still leaves its room to the waveform", (tester) async {
      setPhone(tester: tester, width: 390);
      await _pumpComposer(
        tester: tester,
        voiceCubit: voiceCubit,
        mode: ChatInputMode.voiceFirst,
        initialText: "draft words",
      );
      final sendRect = tester.getRect(send);

      final gesture = await hold(tester: tester, mode: ChatInputMode.voiceFirst);
      expect(tester.getRect(send), sendRect);
      expect(_shownOpacity(send), 0);
      expect(tester.getTopRight(waveform).dx, greaterThan(sendRect.right - 44));

      await gesture.up();
      await tester.pump();
      await complete(tester: tester, transcript: "spoken words", outcome: VoiceDictationOutcome.finished);
    });
  });

  for (final (name, icon, draft, tooltip, offersTap)
      in <(String, IconData, String, String, bool Function(SemanticsNode))>[
        // The keyboard button's tap merges into the node it shares with the pill's
        // others, so only that node's own actions say anything about it.
        (
          "keyboard",
          TablerRegular.keyboard,
          "",
          "Type a message",
          (node) => node.getSemanticsData().hasAction(SemanticsAction.tap),
        ),
        ("send", TablerRegular.arrow_up, "draft words", "Send", _offersTap),
      ]) {
    group("voice-first's $name button fades where it rests", () {
      final action = find.byIcon(icon);
      final button = find.ancestor(of: action, matching: find.byType(Tooltip)).first;
      final stop = find.byIcon(TablerSolid.player_stop);
      final waveform = find.byType(PregoVoiceWaveform);
      final holdLabel = find.textContaining("Hold to talk");

      void setPhone({required WidgetTester tester, required double width}) {
        tester.view.physicalSize = Size(width * 3, 844 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
      }

      for (final (screen, width, textScale, isBusy) in [
        ("phone", 390.0, 1.0, false),
        ("while busy", 390.0, 1.0, true),
        ("small and large text", 320.0, 2.0, false),
      ]) {
        for (final cancels in [false, true]) {
          testWidgets("through a whole hold ending in ${cancels ? "a cancel" : "a release"}, $screen", (tester) async {
            setPhone(tester: tester, width: width);
            tester.platformDispatcher.textScaleFactorTestValue = textScale;
            addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
            await _pumpComposer(
              tester: tester,
              voiceCubit: voiceCubit,
              mode: ChatInputMode.voiceFirst,
              initialText: draft,
              isBusy: isBusy,
            );
            final rect = tester.getRect(button);
            final stopLeft = stop.evaluate().isEmpty ? null : tester.getTopLeft(stop).dx;
            final composerHeight = tester.getSize(find.byType(PromptInput)).height;

            void expectAtRest({required String frame}) {
              final now = tester.getRect(button);
              expect(now.left, rect.left, reason: "moved at $frame");
              expect(now.top, closeTo(rect.top, 0.01), reason: "rose at $frame");
              expect(
                _shownRect(tester: tester, finder: button).width,
                rect.width,
                reason: "clipped at $frame",
              );
              if (stopLeft != null) expect(tester.getTopLeft(stop).dx, stopLeft, reason: "stop moved at $frame");
            }

            final gesture = await tester.startGesture(tester.getCenter(holdLabel));
            await tester.pump();
            expectAtRest(frame: "press");
            var waveformRight = tester.getRect(waveform).right;
            final waveformRestingRight = waveformRight;
            for (var ms = 16; ms <= 288; ms += 16) {
              await tester.pump(const Duration(milliseconds: 16));
              final faded = Curves.easeOutCubic.transform((ms / 220).clamp(0.0, 1.0));
              expect(_shownOpacity(action), closeTo(1 - faded, 0.03), reason: "the house fade, holding, $ms ms");
              expectAtRest(frame: "holding, $ms ms");
              final right = tester.getRect(waveform).right;
              expect(right, greaterThanOrEqualTo(waveformRight), reason: "The waveform opens into the room.");
              waveformRight = right;
            }
            expect(_shownOpacity(action), 0);
            expect(
              waveformRight,
              greaterThan(waveformRestingRight + rect.width),
              reason: "It takes the button's room.",
            );

            if (cancels) {
              await gesture.moveTo(abovePill(tester: tester, by: 64));
              await tester.pump();
            }
            await gesture.up();
            await tester.pump();
            expectAtRest(frame: "release");
            for (var ms = 16; ms <= 288; ms += 16) {
              await tester.pump(const Duration(milliseconds: 16));
              final t = (ms / 220).clamp(0.0, 1.0);
              expect(
                _shownOpacity(action),
                closeTo(
                  Curves.easeOutCubic.transform(t) * const Interval(0.6, 1, curve: Curves.easeOutCubic).transform(t),
                  0.01,
                ),
                reason: "the tasks pill's return, $ms ms",
              );
              expectAtRest(frame: "releasing, $ms ms");
              if (waveform.evaluate().isEmpty) continue;
              final right = tester.getRect(waveform).right;
              expect(right, lessThanOrEqualTo(waveformRight), reason: "The waveform gives the room back.");
              waveformRight = right;
              if (right > rect.left) {
                expect(_shownOpacity(action), 0, reason: "It would show over the waveform's end, $ms ms");
              }
            }
            expect(_shownOpacity(action), 1);
            if (!cancels) {
              await complete(tester: tester, transcript: "spoken words", outcome: VoiceDictationOutcome.finished);
            }
            await tester.pump(const Duration(milliseconds: 500));
            // A release sends the draft, and an empty box has no send button.
            if (draft.isEmpty || cancels) {
              expect(tester.getSize(find.byType(PromptInput)).height, composerHeight);
              expectAtRest(frame: "after");
            }
          });
        }
      }

      testWidgets("reduced motion swaps the button and its room at once", (tester) async {
        setPhone(tester: tester, width: 390);
        tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
          disableAnimations: true,
        );
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: ChatInputMode.voiceFirst, initialText: draft);
        final rect = tester.getRect(button);

        final gesture = await tester.startGesture(tester.getCenter(holdLabel));
        await tester.pump();
        expect(_shownOpacity(action), 0);
        final openRight = tester.getRect(waveform).right;
        expect(openRight, greaterThan(rect.left + rect.width / 2), reason: "The room is the waveform's already.");
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.getRect(waveform).right, openRight, reason: "Nothing eases on afterwards.");

        await gesture.up();
        await tester.pump();
        expect(_shownOpacity(action), 1);
        expect(tester.getRect(button), rect);
        expect(button.hitTestable(), findsOne, reason: "Nothing holds it back once it shows.");
        expect(tester.getRect(waveform).right, lessThanOrEqualTo(rect.left), reason: "The room comes back as fast.");
        await complete(tester: tester, transcript: "spoken words", outcome: VoiceDictationOutcome.finished);
      });

      testWidgets("a hidden button takes no touch, focus or screen reader tap, then comes back", (tester) async {
        setPhone(tester: tester, width: 390);
        final semantics = tester.ensureSemantics();
        await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: ChatInputMode.voiceFirst, initialText: draft);
        bool excludesFocus() => tester
            .widgetList<ExcludeFocus>(find.ancestor(of: action, matching: find.byType(ExcludeFocus)))
            .any((exclude) => exclude.excluding);
        final forScreenReader = find.semantics.byPredicate(
          (node) => node.getSemanticsData().tooltip == tooltip,
        );
        bool screenReaderCanTap() => offersTap(tester.getSemantics(action));
        expect(button.hitTestable(), findsOne);
        expect(screenReaderCanTap(), isTrue);
        expect(excludesFocus(), isFalse);

        final gesture = await tester.startGesture(tester.getCenter(holdLabel));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(_shownOpacity(action), greaterThan(0.5), reason: "Still mostly visible, and already dead.");
        expect(button.hitTestable(), findsNothing);
        expect(screenReaderCanTap(), isFalse);
        expect(excludesFocus(), isTrue);

        await tester.pump(const Duration(milliseconds: 300));
        expect(forScreenReader, findsNothing, reason: "Nothing to read out once it has gone.");
        expect(button.hitTestable(), findsNothing);

        await gesture.moveTo(abovePill(tester: tester, by: 64));
        await tester.pump();
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 128));
        expect(_shownOpacity(action), 0);
        expect(button.hitTestable(), findsNothing, reason: "Back in its place, but nothing shows yet.");
        expect(screenReaderCanTap(), isFalse);
        expect(excludesFocus(), isTrue);

        await tester.pump(const Duration(milliseconds: 16));
        expect(_shownOpacity(action), greaterThan(0));
        expect(button.hitTestable(), findsOne, reason: "Tappable as soon as it shows.");
        expect(excludesFocus(), isFalse);

        await tester.pump(const Duration(milliseconds: 100));
        expect(screenReaderCanTap(), isTrue);
        semantics.dispose();
      });
    });
  }

  group("voice-first's trailing room", () {
    final room = find.byWidgetPredicate((widget) => widget is AnimatedSize && widget.child is SizedBox);
    final keyboard = find.byIcon(TablerRegular.keyboard);
    final stop = find.byIcon(TablerSolid.player_stop);
    final send = find.byIcon(TablerRegular.arrow_up);

    Rect actionRect({required WidgetTester tester, required Finder icon}) =>
        tester.getRect(find.ancestor(of: icon, matching: find.byType(Tooltip)).first);

    VoidCallback? sendCallback({required WidgetTester tester}) =>
        tester.widget<PregoButtonsSolid>(find.ancestor(of: send, matching: find.byType(PregoButtonsSolid))).onPressed;

    void expectRoomFits({required WidgetTester tester, required Finder first, required Finder last}) {
      final shown = tester.getRect(room);
      expect(shown.left, actionRect(tester: tester, icon: first).left);
      expect(shown.right, actionRect(tester: tester, icon: last).right);
    }

    for (final (screen, width, textScale) in [("phone", 390.0, 1.0), ("small and large text", 320.0, 2.0)]) {
      void setScreen({required WidgetTester tester}) {
        tester.view.physicalSize = Size(width * 3, 844 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      }

      testWidgets("matches the keyboard button, $screen", (tester) async {
        setScreen(tester: tester);
        await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: ChatInputMode.voiceFirst);
        expectRoomFits(tester: tester, first: keyboard, last: keyboard);
      });

      testWidgets("matches the keyboard and stop buttons, $screen", (tester) async {
        setScreen(tester: tester);
        await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: ChatInputMode.voiceFirst, isBusy: true);
        expectRoomFits(tester: tester, first: keyboard, last: stop);
      });

      for (final presentation in ComposerPresentation.values) {
        testWidgets("matches send, enabled, ${presentation.name}, $screen", (tester) async {
          setScreen(tester: tester);
          await _pumpComposer(
            tester: tester,
            voiceCubit: voiceCubit,
            mode: ChatInputMode.voiceFirst,
            initialText: "draft words",
            presentation: presentation,
          );
          expect(find.byType(PregoVoiceSendButton), findsNothing, reason: "Its wide form isn't this pill's.");
          expectRoomFits(tester: tester, first: send, last: send);
        });
      }

      testWidgets("matches send while it can't send, $screen", (tester) async {
        setScreen(tester: tester);
        await _pumpComposer(
          tester: tester,
          voiceCubit: voiceCubit,
          mode: ChatInputMode.voiceFirst,
          initialText: "draft words",
          canSend: false,
        );
        expect(sendCallback(tester: tester), isNull);
        expectRoomFits(tester: tester, first: send, last: send);
      });

      testWidgets("matches send while it waits for dictated words, and send stays disabled, $screen", (tester) async {
        setScreen(tester: tester);
        final composer = await _pumpComposer(
          tester: tester,
          voiceCubit: voiceCubit,
          mode: ChatInputMode.voiceFirst,
          initialText: "draft words",
        );
        final rect = actionRect(tester: tester, icon: send);

        final gesture = await hold(tester: tester, mode: ChatInputMode.voiceFirst);
        await gesture.up();
        await tester.pump();
        for (final ms in [16, 128, 16, 64, 300]) {
          await tester.pump(Duration(milliseconds: ms));
          await tester.tapAt(rect.center);
          await tester.pump();
          expect(composer.sent, isEmpty, reason: "The box waits for the words on their way.");
        }
        expect(sendCallback(tester: tester), isNull);
        expect(actionRect(tester: tester, icon: send), rect);
        expectRoomFits(tester: tester, first: send, last: send);

        await complete(tester: tester, transcript: "spoken", outcome: VoiceDictationOutcome.finished);
        expect(composer.sent, [(text: "draft words spoken", command: null)]);
      });
    }
  });

  group("voice-first's actions take no tap until they start to show", () {
    final keyboard = find.byIcon(TablerRegular.keyboard);
    final stop = find.byIcon(TablerSolid.player_stop);
    final send = find.byIcon(TablerRegular.arrow_up);

    void setPhone({required WidgetTester tester}) {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    Future<void> cancelHold({required WidgetTester tester}) async {
      final gesture = await hold(tester: tester, mode: ChatInputMode.voiceFirst);
      await gesture.moveTo(abovePill(tester: tester, by: 64));
      await tester.pump();
      await gesture.up();
      await tester.pump();
    }

    /// A tap that started a hold has only ended it once the first pump's time
    /// has passed, and the buttons' return runs from there.
    Future<void> settleAfterTap({required WidgetTester tester}) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    // 132 ms is where the fade back in starts. At 0 and 16 ms the room hasn't
    // closed, so the tap lands on the hold surface as it always has.
    for (final delay in const [0, 16, 48, 96, 128]) {
      testWidgets("send, $delay ms after a cancel, keeps the draft", (tester) async {
        setPhone(tester: tester);
        final composer = await _pumpComposer(
          tester: tester,
          voiceCubit: voiceCubit,
          mode: ChatInputMode.voiceFirst,
          initialText: "draft words",
        );
        final spot = tester.getCenter(send);

        await cancelHold(tester: tester);
        await tester.pump(Duration(milliseconds: delay));
        await tester.tapAt(spot);
        await settleAfterTap(tester: tester);
        expect(composer.sent, isEmpty);
        expect(find.text("draft words"), findsOneWidget);

        await tester.tapAt(spot);
        await tester.pump();
        expect(composer.sent, [(text: "draft words", command: null)]);
      });

      testWidgets("send, $delay ms after words reach the box, keeps them there", (tester) async {
        setPhone(tester: tester);
        final composer = await _pumpComposer(
          tester: tester,
          voiceCubit: voiceCubit,
          mode: ChatInputMode.voiceFirst,
          initialText: "draft words",
        );
        final spot = tester.getCenter(send);

        final gesture = await hold(tester: tester, mode: ChatInputMode.voiceFirst);
        await slideOntoPencil(tester: tester, gesture: gesture);
        await gesture.up();
        await tester.pump();
        await emitVoice(
          tester: tester,
          state: const VoiceInputState.completed(
            transcript: "spoken",
            outcome: VoiceDictationOutcome.finished,
            mode: VoiceDictationMode.afterRecording,
          ),
        );
        await emitVoice(tester: tester, state: const VoiceInputState.idle());
        await tester.pump(Duration(milliseconds: delay));
        await tester.tapAt(spot);
        await settleAfterTap(tester: tester);
        expect(composer.sent, isEmpty);

        await tester.tapAt(spot);
        await tester.pump();
        expect(composer.sent, [(text: "draft words spoken", command: null)]);
      });

      testWidgets("stop, $delay ms after a cancel, doesn't stop the work", (tester) async {
        setPhone(tester: tester);
        final composer = await _pumpComposer(
          tester: tester,
          voiceCubit: voiceCubit,
          mode: ChatInputMode.voiceFirst,
          isBusy: true,
        );
        final spot = tester.getCenter(stop);

        await cancelHold(tester: tester);
        await tester.pump(Duration(milliseconds: delay));
        await tester.tapAt(spot);
        await settleAfterTap(tester: tester);
        expect(composer.aborts, 0);

        await tester.tapAt(spot);
        await tester.pump();
        expect(composer.aborts, 1);
      });

      testWidgets("keyboard, $delay ms after a cancel, stays the resting pill", (tester) async {
        setPhone(tester: tester);
        await _pumpComposer(tester: tester, voiceCubit: voiceCubit, mode: ChatInputMode.voiceFirst);
        final spot = tester.getCenter(keyboard);

        await cancelHold(tester: tester);
        await tester.pump(Duration(milliseconds: delay));
        await tester.tapAt(spot);
        await settleAfterTap(tester: tester);
        expect(keyboard, findsOneWidget);

        await tester.tapAt(spot);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(keyboard, findsNothing);
      });
    }
  });
}

/// Whether a screen reader can tap [node] or, as with a button in its tooltip, a node under it.
bool _offersTap(SemanticsNode node) {
  if (node.getSemanticsData().hasAction(SemanticsAction.tap)) return true;
  var found = false;
  node.visitChildren((child) {
    found = _offersTap(child);
    return !found;
  });
  return found;
}

/// What of [finder] shows once the clipping ancestors have had their way.
Rect _shownRect({required WidgetTester tester, required Finder finder}) {
  var shown = tester.getRect(finder);
  RenderObject? render = finder.evaluate().first.renderObject?.parent;
  while (render != null) {
    final clips = render is RenderClipRect || (render is RenderAnimatedSize && render.clipBehavior != Clip.none);
    if (clips && render is RenderBox) shown = shown.intersect(render.localToGlobal(Offset.zero) & render.size);
    render = render.parent;
  }
  return shown;
}

/// The rest of the composer's chrome differs by mode; the hold starts on the
/// pill in voice-first and on the mic in text-first.
Finder _holdTarget({required ChatInputMode mode}) => switch (mode) {
  ChatInputMode.voiceFirst => find.textContaining("Hold to talk"),
  ChatInputMode.textFirst => find.byIcon(TablerRegular.microphone),
};

/// The words at rest where the waveform shows during a hold.
Finder _restingWords({required ChatInputMode mode}) => switch (mode) {
  ChatInputMode.voiceFirst => find.textContaining("Hold to talk"),
  ChatInputMode.textFirst => find.text("Follow up..."),
};

/// How opaque [finder] looks on screen, across every copy of it still fading.
double _shownOpacity(Finder finder) {
  var hidden = 1.0;
  for (final element in finder.evaluate()) {
    var opacity = 1.0;
    RenderObject? render = element.renderObject;
    while (render != null) {
      if (render is RenderAnimatedOpacity) opacity *= render.opacity.value;
      render = render.parent;
    }
    hidden *= 1 - opacity;
  }
  return 1 - hidden;
}

Future<_Composer> _pumpComposer({
  required WidgetTester tester,
  required VoiceInputCubit voiceCubit,
  required ChatInputMode mode,
  String initialText = "",
  bool canSend = true,
  CommandInfo? stagedCommand,
  Widget? composerHeader,
  Widget? composerTrailing,
  bool isBusy = false,
  ComposerPresentation presentation = ComposerPresentation.touch,
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
      builder: (context, child) => SentBubbleLanding(child: child ?? const SizedBox.shrink()),
      home: BlocProvider<VoiceInputCubit>.value(
        value: voiceCubit,
        child: ComposerPresentationScope(
          voiceSupport: ComposerVoiceSupport.supported,
          inputMode: mode,
          isKeyboardVisible: false,
          sendKeyPolicy: ComposerSendKeyPolicy.enterSends,
          presentation: presentation,
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
                canSend: canSend,
                onSend: ({required draft, required command, required attachments}) {
                  composer.sent.add((text: draft.text, command: command));
                },
                onVoiceTranscriptionFinished: ({required finish, required mode}) {
                  composer.finishes.add(finish);
                  composer.modes.add(mode);
                },
                onDraftChanged: (_) {},
                onDraftCleared: () {},
                onAbort: () => composer.aborts++,
                surfaceStyleController: surfaceStyle,
                composerHeader: composerHeader,
                composerTrailing: composerTrailing,
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
