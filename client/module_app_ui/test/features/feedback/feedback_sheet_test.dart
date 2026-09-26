import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/feedback/feedback_rating_motion.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

class _MockAppReviewClient() extends Mock implements AppReviewClient;

const _ratingTitle = "Are you enjoying Sesori?";
const _reviewTitle = "Thanks! Leave a review?";
const _reviewBody = "It takes a minute and helps other developers find Sesori.";

void main() {
  late FeedbackSheetCubit cubit;
  late List<FeedbackSheetOutcome> outcomes;
  late List<bool> sheetsAtOutcome;

  setUp(() {
    cubit = FeedbackSheetCubit(appReviewClient: _MockAppReviewClient());
    outcomes = [];
    sheetsAtOutcome = [];
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
                final outcome = await showFeedbackSheet(context: context, cubit: cubit);
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

  testWidgets("closing before answering dismisses, and Could be better resolves as such", (tester) async {
    await open(tester: tester);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel("Close feedback"), findsOneWidget);
    semantics.dispose();
    await tapAndSettle(tester: tester, finder: close);

    await tester.tap(find.text("Open"));
    await tester.pumpAndSettle();
    await tapAndSettle(tester: tester, finder: improve);

    expect(outcomes, [isA<FeedbackSheetOutcomeDismissed>(), isA<FeedbackSheetOutcomeCouldBeBetter>()]);
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

  testWidgets("a narrow screen with large text fits both steps", (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester: tester, size: const Size(320, 568));
    expect(tester.takeException(), isNull);
    await tapAndSettle(tester: tester, finder: love);
    expect(find.text(_reviewTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
