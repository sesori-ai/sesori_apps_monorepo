import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/feedback/feedback_rating_motion.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

class _MockAppReviewClient() extends Mock implements AppReviewClient;

class _MockFeedbackRepository() extends Mock implements FeedbackRepository;

class _MockVoiceTranscriptionService() extends Mock implements VoiceTranscriptionService;

class _MockVoiceTranscriptionSession() extends Mock implements VoiceTranscriptionSession;

const _ratingTitle = "Are you enjoying Sesori?";
const _reviewTitle = "Thanks! Leave a review?";
const _reviewBody = "It takes a minute and helps other developers find Sesori.";

void main() {
  late _MockFeedbackRepository feedbackRepository;
  late FeedbackSheetCubit cubit;
  late List<FeedbackSheetOutcome> outcomes;
  late List<bool> sheetsAtOutcome;
  late _MockVoiceTranscriptionService voiceService;
  late List<VoiceInputCubit> voiceCubits;

  setUpAll(() {
    registerFallbackValue(<FeedbackIssue>{});
    registerFallbackValue(FeedbackSource.settings);
    registerFallbackValue(_MockVoiceTranscriptionSession());
  });

  setUp(() {
    feedbackRepository = _MockFeedbackRepository();
    cubit = FeedbackSheetCubit(
      appReviewClient: _MockAppReviewClient(),
      feedbackRepository: feedbackRepository,
      feedbackPromptService: FakeFeedbackPromptService(),
      source: FeedbackSource.settings,
    );
    outcomes = [];
    sheetsAtOutcome = [];
    voiceService = _MockVoiceTranscriptionService();
    voiceCubits = [];
    // Created per test, so closing a recorder settles inside the fake clock.
    final maxDurationReached = StreamController<void>.broadcast();
    addTearDown(maxDurationReached.close);
    when(
      () => voiceService.maxDurationReachedStream(session: any(named: "session")),
    ).thenAnswer((_) => maxDurationReached.stream);
    // The recorder's level stream is broadcast, like the real capture's.
    final levels = StreamController<double>.broadcast();
    addTearDown(levels.close);
    when(() => voiceService.amplitudeStream(session: any(named: "session"))).thenAnswer((_) => levels.stream);
    when(() => voiceService.prewarm(session: any(named: "session"))).thenAnswer((_) async {});
    when(() => voiceService.start(session: any(named: "session"))).thenAnswer((_) async {});
    when(() => voiceService.cancel(session: any(named: "session"))).thenAnswer((_) async {});
    when(() => voiceService.discard(session: any(named: "session"))).thenAnswer((_) async {});
    when(() => voiceService.close(session: any(named: "session"))).thenAnswer((_) async {});
  });

  tearDown(() => cubit.close());

  Future<void> open({required WidgetTester tester, Size size = const Size(390, 844)}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPregoThemeData(brightness: Brightness.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                final outcome = await showFeedbackSheet(
                  context: context,
                  cubit: cubit,
                  voiceInputScopeBuilder: ({required child}) => BlocProvider(
                    create: (_) {
                      final voiceCubit = VoiceInputCubit(
                        service: voiceService,
                        session: _MockVoiceTranscriptionSession(),
                      );
                      voiceCubits.add(voiceCubit);
                      return voiceCubit;
                    },
                    child: child,
                  ),
                );
                outcomes.add(outcome);
                sheetsAtOutcome.add(find.byType(BottomSheet, skipOffstage: false).evaluate().isNotEmpty);
              },
              child: const Text("Open"),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("Open"));
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle({required WidgetTester tester, required Finder finder}) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  final love = find.byKey(const ValueKey("feedback-love"));
  final improve = find.byKey(const ValueKey("feedback-improve"));
  final close = find.byKey(const ValueKey("feedback-close"));
  final leaveReview = find.byKey(const ValueKey("feedback-leave-review"));
  final notNow = find.byKey(const ValueKey("feedback-not-now"));
  final text = find.byKey(const ValueKey("feedback-text"));
  final send = find.byKey(const ValueKey("feedback-send"));
  final cancel = find.byKey(const ValueKey("feedback-cancel"));

  void answerSubmit(Future<void> Function() answer) => when(
    () => feedbackRepository.submit(
      issues: any(named: "issues"),
      message: any(named: "message"),
      source: any(named: "source"),
    ),
  ).thenAnswer((_) => answer());

  testWidgets("Yes keeps the authored opening, locks both answers, then asks for a review", (tester) async {
    await open(tester: tester);
    final heroAnimation = tester.widget<FeedbackRatingHero>(find.byType(FeedbackRatingHero)).animation;
    expect(tester.widget<FeedbackLoveButton>(find.byType(FeedbackLoveButton)).animation, same(heroAnimation));

    await tester.tap(love);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(heroAnimation.value, closeTo(0.25, 0.0001), reason: "The first 1.2s retain the authored Figma timing.");
    expect(tester.widget<TextButton>(love).onPressed, isNull);
    expect(tester.widget<TextButton>(improve).onPressed, isNull);

    await tester.pump(const Duration(milliseconds: 700));
    expect(heroAnimation.value, closeTo(0.6, 0.0001));
    await tester.pump(const Duration(milliseconds: 299));
    expect(find.text(_ratingTitle), findsOneWidget);
    expect(find.text(_reviewTitle), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.text(_ratingTitle), findsNothing);
    expect(find.text(_reviewTitle), findsOneWidget);
    expect(find.text(_reviewBody), findsOneWidget);
    // The hero stays in place: only the answers hand over to the question.
    expect(tester.widget<FeedbackRatingHero>(find.byType(FeedbackRatingHero)).animation, same(heroAnimation));
    expect(outcomes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    "Leave a review resolves only after the sheet has fully closed",
    (tester) async {
      await open(tester: tester);
      await tapAndSettle(tester: tester, finder: love);
      expect(find.text(_reviewBody), findsOneWidget);

      await tester.tap(leaveReview);
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(outcomes, isEmpty, reason: "The store must wait for the closing sheet animation.");
      expect(find.byType(BottomSheet, skipOffstage: false), findsOneWidget);

      await tester.pumpAndSettle();
      expect(outcomes.single, isA<FeedbackSheetOutcomeLoveLeaveReview>());
      expect(sheetsAtOutcome, [false]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets("an automatic sheet with an in-app OS prompt closes itself after the celebration", (tester) async {
    final appReviewClient = _MockAppReviewClient();
    when(() => appReviewClient.requestReviewOpensStore).thenReturn(false);
    await cubit.close();
    cubit = FeedbackSheetCubit(
      appReviewClient: appReviewClient,
      feedbackRepository: feedbackRepository,
      feedbackPromptService: FakeFeedbackPromptService(),
      source: FeedbackSource.automatic,
    );
    await open(tester: tester);

    await tester.tap(love);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 16));
    // The sheet leaves on the celebration's last frame, with no confirmation.
    expect(find.byType(BottomSheet, skipOffstage: false), findsOneWidget);
    expect(find.text(_ratingTitle), findsOneWidget);
    expect(find.text(_reviewTitle), findsNothing);
    expect(outcomes, isEmpty, reason: "The OS prompt must wait for the closing sheet animation.");

    await tester.pumpAndSettle();
    expect(outcomes.single, isA<FeedbackSheetOutcomeLoveLeaveReview>());
    expect(sheetsAtOutcome, [false]);
    expect(tester.takeException(), isNull);
  });

  testWidgets("a celebration that ends while the sheet closes does not switch to the review step", (tester) async {
    await open(tester: tester);
    await tester.tap(love);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1400));

    await tester.tap(close);
    await tester.pump();
    // The celebration completes 100 ms into the 200 ms exit animation.
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(BottomSheet, skipOffstage: false), findsOneWidget);
    expect(cubit.state, const FeedbackSheetState.celebrating());

    await tester.pumpAndSettle();
    expect(outcomes.single, isA<FeedbackSheetOutcomeLoveNotNow>());
    expect(tester.takeException(), isNull);
  });

  testWidgets("Not now and closing mid-celebration both keep the positive answer without a review", (tester) async {
    await open(tester: tester);
    await tapAndSettle(tester: tester, finder: love);
    await tapAndSettle(tester: tester, finder: notNow);

    await tester.tap(find.text("Open"));
    await tester.pumpAndSettle();
    expect(find.text(_ratingTitle), findsOneWidget, reason: "Reopening starts fresh.");
    await tester.tap(love);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tapAndSettle(tester: tester, finder: close);

    expect(outcomes, [
      isA<FeedbackSheetOutcomeLoveNotNow>(),
      isA<FeedbackSheetOutcomeLoveNotNow>(),
    ]);
    expect(find.byType(BottomSheet, skipOffstage: false), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("closing before answering dismisses, and cancelling private feedback sends nothing", (tester) async {
    await open(tester: tester);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel("Close feedback"), findsOneWidget);
    semantics.dispose();
    await tapAndSettle(tester: tester, finder: close);

    await tester.tap(find.text("Open"));
    await tester.pumpAndSettle();
    await tapAndSettle(tester: tester, finder: improve);
    expect(find.text("What should we improve?"), findsOneWidget);
    expect(find.text(_ratingTitle), findsNothing);
    await tapAndSettle(tester: tester, finder: cancel);

    expect(outcomes, [
      isA<FeedbackSheetOutcomeDismissed>(),
      isA<FeedbackSheetOutcomeCouldBeBetter>().having((o) => o.sent, "sent", isFalse),
    ]);
    verifyZeroInteractions(feedbackRepository);
    expect(tester.takeException(), isNull);
  });

  testWidgets("Send submits the ticked issues and text, closes, then confirms with a toast", (tester) async {
    final pending = Completer<void>();
    answerSubmit(() => pending.future);
    await open(tester: tester);
    await tapAndSettle(tester: tester, finder: improve);

    await tapAndSettle(tester: tester, finder: find.text("Connection drops"));
    await tester.enterText(text, "Fixture feedback");
    await tester.tap(send);
    await tester.pump();

    verify(
      () => feedbackRepository.submit(
        issues: {FeedbackIssue.connectionDrops},
        message: "Fixture feedback",
        source: FeedbackSource.settings,
      ),
    ).called(1);
    expect(tester.widget<TextField>(text).readOnly, isTrue, reason: "The draft is locked while sending.");

    pending.complete();
    await tester.pumpAndSettle();
    expect(outcomes.single, isA<FeedbackSheetOutcomeCouldBeBetter>().having((o) => o.sent, "sent", isTrue));
    expect(sheetsAtOutcome, [false]);
    expect(find.text("Feedback sent. Thank you!"), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets("the sheet cannot be dismissed while a send is in flight", (tester) async {
    final pending = Completer<void>();
    answerSubmit(() => pending.future);
    await open(tester: tester);
    await tapAndSettle(tester: tester, finder: improve);
    expect(find.text("Sent privately to the Sesori team."), findsOneWidget);
    await tester.enterText(text, "Fixture feedback");
    await tester.tap(send);
    await tester.pump();

    // The send button's spinner never settles, so pump a second of frames.
    Future<void> pumpASecond() async {
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    expect(tester.widget<TextButton>(cancel).onPressed, isNull);
    await tester.tapAt(const Offset(20, 20));
    await pumpASecond();
    await tester.binding.handlePopRoute();
    await pumpASecond();
    await tester.drag(find.text("What should we improve?"), const Offset(0, 600));
    await pumpASecond();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text("What should we improve?"), findsOneWidget);
    expect(outcomes, isEmpty);

    pending.complete();
    await tester.pumpAndSettle();
    expect(outcomes.single, isA<FeedbackSheetOutcomeCouldBeBetter>().having((o) => o.sent, "sent", isTrue));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets("a failed send keeps the draft and Retry sends it again", (tester) async {
    answerSubmit(() async => throw StateError("offline"));
    await open(tester: tester);
    await tapAndSettle(tester: tester, finder: improve);
    await tester.enterText(text, "Fixture feedback");
    await tapAndSettle(tester: tester, finder: send);

    expect(find.text("Couldn’t send feedback. Your draft is still here."), findsOneWidget);
    expect(find.text("Fixture feedback"), findsOneWidget);
    expect(outcomes, isEmpty);

    answerSubmit(() async {});
    await tapAndSettle(tester: tester, finder: find.byKey(const ValueKey("feedback-retry")));
    verify(
      () => feedbackRepository.submit(issues: {}, message: "Fixture feedback", source: FeedbackSource.settings),
    ).called(2);
    expect(outcomes.single, isA<FeedbackSheetOutcomeCouldBeBetter>().having((o) => o.sent, "sent", isTrue));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets("the text stops at 4,000 characters and counts down near the limit", (tester) async {
    await open(tester: tester);
    await tapAndSettle(tester: tester, finder: improve);
    final counter = find.byKey(const ValueKey("feedback-counter"));

    await tester.enterText(text, "a" * 3700);
    await tester.pump();
    expect(counter, findsNothing);

    await tester.enterText(text, "a" * 3850);
    await tester.pump();
    expect(find.text("150 characters left"), findsOneWidget);

    await tester.enterText(text, "a" * 4100);
    await tester.pump();
    expect(tester.widget<TextField>(text).controller?.text.length, 4000);
    expect(find.text("0 characters left"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (label, features) in [
    ("disableAnimations", const FakeAccessibilityFeatures(disableAnimations: true)),
    ("reduceMotion", const FakeAccessibilityFeatures(reduceMotion: true)),
  ]) {
    testWidgets("$label removes sheet travel and skips the celebration", (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = features;
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await open(tester: tester);
      final route = ModalRoute.of(tester.element(find.byType(BottomSheet)));
      expect(route?.transitionDuration, Duration.zero);
      expect(route?.reverseTransitionDuration, Duration.zero);

      final began = tester.binding.clock.now();
      await tapAndSettle(tester: tester, finder: love);
      expect(tester.binding.clock.now().difference(began), lessThan(const Duration(milliseconds: 500)));
      expect(find.text(_reviewTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("enabling $label during the celebration finishes it promptly", (tester) async {
      await open(tester: tester);
      await tester.tap(love);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final changed = tester.binding.clock.now();
      tester.platformDispatcher.accessibilityFeaturesTestValue = features;
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpAndSettle();
      expect(tester.binding.clock.now().difference(changed), lessThan(const Duration(milliseconds: 500)));
      expect(find.text(_reviewTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets("turning on Reduce Motion keeps the private draft", (tester) async {
    await open(tester: tester);
    await tapAndSettle(tester: tester, finder: improve);
    await tester.enterText(text, "Fixture feedback");

    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpAndSettle();

    expect(find.text("Fixture feedback"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("a narrow screen with large text fits both steps", (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester: tester, size: const Size(320, 568));
    expect(tester.takeException(), isNull);
    await tapAndSettle(tester: tester, finder: love);
    expect(find.text(_reviewTitle), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The small screen scrolls the sheet, so bring each answer into view.
    await tester.ensureVisible(notNow);
    await tapAndSettle(tester: tester, finder: notNow);
    await tester.tap(find.text("Open"));
    await tester.pumpAndSettle();
    await tester.ensureVisible(improve);
    await tapAndSettle(tester: tester, finder: improve);
    await tester.ensureVisible(cancel);
    expect(find.text("Notifications don’t arrive"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group("voice input", () {
    final microphone = find.byKey(const ValueKey("feedback-voice"));
    final waveform = find.byType(PregoVoiceWaveform);
    final transcribing = find.text("Transcribing...");

    String draft(WidgetTester tester) => tester.widget<TextField>(text).controller?.text ?? "";

    bool sendEnabled(WidgetTester tester) => tester.widget<PregoButtonsSolid>(send).onPressed != null;

    Future<void> openPrivateStep({required WidgetTester tester, required String typed}) async {
      await open(tester: tester);
      await tapAndSettle(tester: tester, finder: improve);
      await tester.enterText(text, typed);
      await tester.pump();
    }

    /// Holds the microphone past the tap threshold; the waveform never
    /// settles, so frames are pumped explicitly.
    Future<TestGesture> hold(WidgetTester tester) async {
      final gesture = await tester.startGesture(tester.getCenter(microphone));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      return gesture;
    }

    testWidgets("holding records with a live level and releasing appends the transcript without sending", (
      tester,
    ) async {
      final transcript = Completer<String>();
      when(() => voiceService.stopAndTranscribe(session: any(named: "session"))).thenAnswer((_) => transcript.future);
      await openPrivateStep(tester: tester, typed: "Typed first");
      final draftRect = tester.getRect(text);

      final gesture = await hold(tester);
      expect(waveform, findsOneWidget);
      expect(find.byType(VoiceCancelButton), findsOneWidget);
      expect(sendEnabled(tester), isFalse, reason: "A recording cannot race a send.");
      expect(tester.getRect(text), draftRect, reason: "Recording must not move the draft.");

      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      verify(() => voiceService.stopAndTranscribe(session: any(named: "session"))).called(1);
      expect(transcribing, findsOneWidget);
      expect(waveform, findsNothing);
      expect(draft(tester), "Typed first");

      transcript.complete("  and then spoken. ");
      await tester.pump();
      await tester.pumpAndSettle();
      expect(draft(tester), "Typed first and then spoken.");
      expect(transcribing, findsNothing);
      expect(sendEnabled(tester), isTrue);
      expect(tester.getRect(text), draftRect);
      verifyZeroInteractions(feedbackRepository);
      expect(tester.takeException(), isNull);
    });

    testWidgets("releasing on the cancel target, or a quick tap, discards only the recording", (tester) async {
      await openPrivateStep(tester: tester, typed: "Keep me");

      final gesture = await hold(tester);
      await gesture.moveTo(tester.getCenter(find.byType(VoiceCancelButton)));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      final quickTap = await tester.startGesture(tester.getCenter(microphone));
      await tester.pump(const Duration(milliseconds: 50));
      await quickTap.up();
      await tester.pumpAndSettle();

      verify(() => voiceService.cancel(session: any(named: "session"))).called(2);
      verifyNever(() => voiceService.stopAndTranscribe(session: any(named: "session")));
      expect(draft(tester), "Keep me");
      expect(waveform, findsNothing);
      expect(sendEnabled(tester), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets("a denied microphone explains itself and keeps the draft", (tester) async {
      when(() => voiceService.start(session: any(named: "session"))).thenAnswer(
        (_) async => throw VoiceTranscriptionError.microphonePermissionDenied(innerError: StateError("denied")),
      );
      await openPrivateStep(tester: tester, typed: "Keep me");

      final gesture = await hold(tester);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text("Microphone permission is required for voice input"), findsOneWidget);
      expect(draft(tester), "Keep me");
      expect(waveform, findsNothing);
      expect(sendEnabled(tester), isTrue);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets("a transcription that fails in transit drops the recording, keeps the draft, and records again", (
      tester,
    ) async {
      when(
        () => voiceService.stopAndTranscribe(session: any(named: "session")),
      ).thenAnswer((_) async => throw VoiceTranscriptionError.networkError());
      await openPrivateStep(tester: tester, typed: "Keep me");

      final gesture = await hold(tester);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text("Transcription failed. Record again or type instead."), findsOneWidget);
      verify(() => voiceService.discard(session: any(named: "session"))).called(1);
      expect(draft(tester), "Keep me");
      expect(sendEnabled(tester), isTrue);

      final again = await hold(tester);
      expect(waveform, findsOneWidget, reason: "A fresh recording starts after the failure.");
      await again.up();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets("the draft and the recording survive turning on Reduce Motion mid-recording", (tester) async {
      when(() => voiceService.stopAndTranscribe(session: any(named: "session"))).thenAnswer((_) async => "spoken");
      await openPrivateStep(tester: tester, typed: "Typed");

      final gesture = await hold(tester);
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(waveform, findsOneWidget);
      expect(draft(tester), "Typed");

      await gesture.up();
      await tester.pumpAndSettle();
      expect(voiceCubits, hasLength(1), reason: "The layout switch must not replace the recorder.");
      expect(voiceCubits.single.isClosed, isFalse);
      expect(draft(tester), "Typed spoken");
      expect(tester.takeException(), isNull);
    });

    testWidgets("a transcript stops at the 4,000-character limit", (tester) async {
      when(() => voiceService.stopAndTranscribe(session: any(named: "session"))).thenAnswer((_) async => "a" * 50);
      await openPrivateStep(tester: tester, typed: "b" * 3980);

      final gesture = await hold(tester);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(draft(tester), "${"b" * 3980} ${"a" * 19}");
      expect(find.text("0 characters left"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("closing the sheet mid-recording closes its recorder", (tester) async {
      await openPrivateStep(tester: tester, typed: "Draft");

      final gesture = await hold(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pump();

      expect(find.byType(BottomSheet, skipOffstage: false), findsNothing);
      // Closing the recorder starts by invalidating its session, which stops
      // the recording; the release that follows transcribes nothing.
      verify(() => voiceService.invalidate(session: any(named: "session"))).called(1);
      verifyNever(() => voiceService.stopAndTranscribe(session: any(named: "session")));
      verifyZeroInteractions(feedbackRepository);
      expect(tester.takeException(), isNull);
    });
  });
}
