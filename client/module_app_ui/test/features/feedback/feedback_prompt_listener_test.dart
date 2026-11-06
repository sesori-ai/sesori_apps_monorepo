import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/repositories/models/analytics_delivery_result.dart";
import "package:sesori_dart_core/testing.dart";
import "package:theme_prego/module_prego.dart";

/// Answers like iOS when [allowsQuestionBeforeReview], like Android otherwise.
class _FakeAppReviewClient({@override required final bool allowsQuestionBeforeReview}) implements AppReviewClient {
  int reviewRequests = 0;

  @override
  Future<void> requestReview() async => reviewRequests++;

  @override
  Future<void> openStoreReviewPage() async {}
}

class _MockFeedbackRepository() extends Mock implements FeedbackRepository;

void main() {
  final question = find.text("Are you enjoying Sesori?");

  setUpAll(() => registerFallbackValue(const ProductAnalyticsEvent.analyticsSchemaReady()));

  Future<FakeFeedbackPromptService> pumpListener({
    required WidgetTester tester,
    required AppReviewClient appReviewClient,
  }) async {
    final feedbackPromptService = FakeFeedbackPromptService();
    addTearDown(feedbackPromptService.promptsController.close);
    final navigatorKey = GlobalKey<NavigatorState>();
    final productAnalyticsService = MockProductAnalyticsService();
    when(
      () => productAnalyticsService.logEvent(
        event: any(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).thenAnswer((_) async => AnalyticsDeliveryResult.acceptedBySdk);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: buildPregoThemeData(brightness: Brightness.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => FeedbackPromptCubit(
                feedbackPromptService: feedbackPromptService,
                appReviewClient: appReviewClient,
                productAnalyticsService: productAnalyticsService,
              ),
            ),
            BlocProvider(
              create: (_) => FeedbackSheetCubit(
                appReviewClient: appReviewClient,
                feedbackRepository: _MockFeedbackRepository(),
                feedbackPromptService: feedbackPromptService,
                productAnalyticsService: productAnalyticsService,
                source: FeedbackSource.automatic,
              ),
            ),
          ],
          child: FeedbackPromptListener(
            navigatorKey: navigatorKey,
            // The rating step never builds the private step's voice scope.
            voiceInputScopeBuilder: ({required child}) => child,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: const Text("Session"),
      ),
    );
    return feedbackPromptService;
  }

  testWidgets("opens the rating sheet over the current screen when the counter claims a showing", (tester) async {
    final appReviewClient = _FakeAppReviewClient(allowsQuestionBeforeReview: true);
    final feedbackPromptService = await pumpListener(tester: tester, appReviewClient: appReviewClient);
    expect(question, findsNothing);

    feedbackPromptService.promptsController.add(null);
    await tester.pump();
    await tester.pump();

    expect(question, findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text("Session", skipOffstage: false), findsOneWidget);
    expect(appReviewClient.reviewRequests, 0);
  });

  testWidgets("requests the in-app review with no sheet where Sesori may not ask first, as on Android", (tester) async {
    final appReviewClient = _FakeAppReviewClient(allowsQuestionBeforeReview: false);
    final feedbackPromptService = await pumpListener(tester: tester, appReviewClient: appReviewClient);

    feedbackPromptService.promptsController.add(null);
    await tester.pumpAndSettle();

    expect(question, findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(appReviewClient.reviewRequests, 1);
  });

  testWidgets("waits 500 ms for a raised keyboard to close before opening the sheet", (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    final feedbackPromptService = await pumpListener(
      tester: tester,
      appReviewClient: _FakeAppReviewClient(allowsQuestionBeforeReview: true),
    );

    feedbackPromptService.promptsController.add(null);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 499));
    expect(question, findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(question, findsOneWidget);
    await tester.pumpAndSettle();
  });
}
