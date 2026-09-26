import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:theme_prego/module_prego.dart";

class _MockAppReviewClient() extends Mock implements AppReviewClient;

class _MockFeedbackRepository() extends Mock implements FeedbackRepository;

void main() {
  testWidgets("opens the rating sheet over the current screen when the counter claims a showing", (tester) async {
    final feedbackPromptService = FakeFeedbackPromptService();
    addTearDown(feedbackPromptService.promptsController.close);
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: buildPregoThemeData(brightness: Brightness.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => FeedbackPromptCubit(feedbackPromptService: feedbackPromptService)),
            BlocProvider(
              create: (_) => FeedbackSheetCubit(
                appReviewClient: _MockAppReviewClient(),
                feedbackRepository: _MockFeedbackRepository(),
                feedbackPromptService: feedbackPromptService,
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
    expect(find.text("Are you enjoying Sesori?"), findsNothing);

    feedbackPromptService.promptsController.add(null);
    await tester.pumpAndSettle();

    expect(find.text("Are you enjoying Sesori?"), findsOneWidget);
    expect(find.text("Session", skipOffstage: false), findsOneWidget);
  });
}
