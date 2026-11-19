import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/src/features/side_chat/side_chat_view.dart";
import "package:sesori_app_ui/src/l10n/app_localizations.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/repositories/models/analytics_delivery_result.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/trackpad_overscroll.dart";

SideChatExchange _exchange({required String id, required String question, required String answer}) =>
    SideChatExchange(id: id, question: question, answer: answer, answerNotice: null, askedAt: 1, answeredAt: 2);

final _earlierChat = SideChat(
  id: "chat-earlier",
  exchanges: [_exchange(id: "e1", question: "Which file holds the parser?", answer: "The lexer file.")],
);
final _newestChat = SideChat(
  id: "chat-newest",
  exchanges: [_exchange(id: "n1", question: "What does the retry do?", answer: "It backs off twice.")],
);

void main() {
  late MockSideChatRepository repository;
  late MockProductAnalyticsService analytics;
  late Completer<ApiResponse<AskSideQuestionResponse>> answer;

  setUpAll(() {
    registerFallbackValue(
      const ProductAnalyticsEvent.sessionActivityViewed(activityState: AnalyticsActivityState.empty),
    );
    registerFallbackValue(DateTime.utc(2026));
  });

  setUp(() {
    repository = MockSideChatRepository();
    analytics = MockProductAnalyticsService();
    when(
      () => analytics.logEvent(
        event: any(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).thenAnswer((_) async => AnalyticsDeliveryResult.acceptedBySdk);
    when(
      () => repository.listSideChats(sessionId: any(named: "sessionId")),
    ).thenAnswer((_) async => ApiResponse.success(SideChatListResponse(sideChats: [_newestChat, _earlierChat])));
    when(
      () => repository.askSideQuestion(
        sessionId: any(named: "sessionId"),
        sideChatId: any(named: "sideChatId"),
        question: any(named: "question"),
      ),
    ).thenAnswer((_) => answer.future);
  });

  Future<void> pumpView(WidgetTester tester, {bool isArchived = false}) async {
    // Made inside the test's fake-async zone, so its answer reaches the cubit.
    answer = Completer();
    final cubit = SideChatCubit(
      repository: repository,
      productAnalyticsService: analytics,
      sessionId: "session-1",
      pluginId: "claude",
      availability: SideQuestionAvailability.available,
      isArchived: isArchived,
      initialQuestion: null,
    );
    addTearDown(cubit.close);
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: SideChatView(
              scrollController: scrollController,
              harnessName: "Claude Code",
              onClose: () {},
              autofocusQuestion: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// A focused field's cursor blinks forever, so the field lets go first.
  Future<void> settle(WidgetTester tester, {Duration step = const Duration(milliseconds: 100)}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle(step);
  }

  PregoButtonsSolid sendButton(WidgetTester tester) =>
      tester.widget<PregoButtonsSolid>(find.byKey(SideChatView.sendButtonKey));

  Future<void> ask(WidgetTester tester, String question) async {
    await tester.enterText(find.byKey(SideChatView.questionFieldKey), question);
    await tester.pump();
    await tester.tap(find.byKey(SideChatView.sendButtonKey));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets("a new chat thinks, then shows the answer", (tester) async {
    await pumpView(tester);
    expect(find.text("Side question"), findsOneWidget);
    expect(find.byKey(SideChatView.newChatButtonKey), findsNothing, reason: "the chat is already new");

    await ask(tester, "Where is the cache?");

    expect(find.text("Where is the cache?"), findsOneWidget);
    expect(find.text("Thinking..."), findsOneWidget);
    expect(find.byKey(SideChatView.questionFieldKey), findsOneWidget);
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, isEmpty);

    answer.complete(
      ApiResponse.success(
        AskSideQuestionResponse.answered(
          sideChatId: "chat-asked",
          exchange: _exchange(id: "a1", question: "Where is the cache?", answer: "In the store module."),
        ),
      ),
    );
    await settle(tester);

    expect(find.text("Thinking..."), findsNothing);
    expect(find.text("In the store module."), findsOneWidget);
    expect(find.byKey(SideChatView.newChatButtonKey), findsOneWidget);
  });

  double earlierButtonX(WidgetTester tester) => tester.getTopLeft(find.byKey(SideChatView.earlierButtonKey)).dx;

  T nearestAbove<T extends Widget>(WidgetTester tester, Key key) => tester.widget<T>(
    find.ancestor(of: find.byKey(key), matching: find.byType(T)).first,
  );

  double newChatOpacity(WidgetTester tester) => nearestAbove<Opacity>(tester, SideChatView.newChatButtonKey).opacity;

  double newChatScale(WidgetTester tester) =>
      nearestAbove<Transform>(tester, SideChatView.newChatButtonKey).transform.entry(0, 0);

  void answerFirstQuestion() => answer.complete(
    ApiResponse.success(
      AskSideQuestionResponse.answered(
        sideChatId: "chat-asked",
        exchange: _exchange(id: "a1", question: "Where is the cache?", answer: "In the store module."),
      ),
    ),
  );

  testWidgets("the header eases New chat in and out while Earlier slides aside", (tester) async {
    await pumpView(tester);
    await ask(tester, "Where is the cache?");
    final startX = earlierButtonX(tester);

    answerFirstQuestion();
    await tester.pump();
    final xs = <double>[earlierButtonX(tester)];
    final opacities = <double>[newChatOpacity(tester)];
    final scales = <double>[newChatScale(tester)];
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 40));
      xs.add(earlierButtonX(tester));
      opacities.add(newChatOpacity(tester));
      scales.add(newChatScale(tester));
    }
    await settle(tester);
    final endX = earlierButtonX(tester);

    expect(endX, lessThan(startX - 40), reason: "Earlier makes room for New chat");
    expect(xs.first, startX, reason: "nothing moves in the first frame");
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i], lessThan(xs[i - 1]), reason: "Earlier slides on every frame");
      expect(opacities[i], greaterThanOrEqualTo(opacities[i - 1]), reason: "New chat fades in");
      expect(scales[i], greaterThan(scales[i - 1]), reason: "New chat grows in");
    }
    expect(xs.last, greaterThan(endX), reason: "the slide is still under way");
    expect(opacities.first, lessThan(0.1));
    expect(opacities.where((opacity) => opacity > 0 && opacity < 1), hasLength(greaterThanOrEqualTo(2)));
    expect(scales.first, closeTo(0.9, 0.01));
    expect(newChatOpacity(tester), 1);
    expect(newChatScale(tester), 1);

    // A new chat takes the button away again, and Earlier slides back.
    await tester.tap(find.byKey(SideChatView.newChatButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(newChatOpacity(tester), allOf(greaterThan(0), lessThan(1)));
    expect(newChatScale(tester), lessThan(1));
    expect(earlierButtonX(tester), allOf(greaterThan(endX), lessThan(startX)));
    await settle(tester);
    expect(find.byKey(SideChatView.newChatButtonKey), findsNothing);
    expect(earlierButtonX(tester), startX);
  });

  testWidgets("under reduced motion the header buttons change at once", (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpView(tester);
    await ask(tester, "Where is the cache?");
    final startX = earlierButtonX(tester);

    answerFirstQuestion();
    await tester.pump();
    final xAfterAnswer = earlierButtonX(tester);
    expect(xAfterAnswer, lessThan(startX - 40));
    expect(newChatOpacity(tester), 1);
    expect(newChatScale(tester), 1);

    await settle(tester);
    expect(earlierButtonX(tester), xAfterAnswer);
  });

  testWidgets("while an answer is on its way the controls look disabled and say why", (tester) async {
    await pumpView(tester);
    await ask(tester, "Where is the cache?");

    await tester.enterText(find.byKey(SideChatView.questionFieldKey), "And the queue?");
    await tester.pump();
    expect(sendButton(tester).onPressed, isNull);

    await tester.tap(find.byKey(SideChatView.sendButtonKey), warnIfMissed: false);
    await tester.pump();
    expect(find.text("Wait for the answer to arrive first."), findsOneWidget);
    verify(
      () => repository.askSideQuestion(
        sessionId: any(named: "sessionId"),
        sideChatId: any(named: "sideChatId"),
        question: any(named: "question"),
      ),
    ).called(1);

    await tester.tap(find.byKey(SideChatView.earlierButtonKey));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text("Earlier side chats"), findsNothing, reason: "the earlier chats stay closed");

    answer.complete(ApiResponse.success(const AskSideQuestionResponse.refused(reason: SideQuestionRefusal.noAnswer)));
    await settle(tester, step: const Duration(seconds: 4));
  });

  testWidgets("a refusal shows its reason in place with Retry and hands the question back", (tester) async {
    await pumpView(tester);
    await ask(tester, "Where is the cache?");

    answer.complete(ApiResponse.success(const AskSideQuestionResponse.refused(reason: SideQuestionRefusal.noAnswer)));
    await settle(tester);

    expect(find.text("No answer came back."), findsOneWidget);
    expect(find.text("Retry"), findsOneWidget);
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, "Where is the cache?");

    // Retry asks the failed question again; a different draft stays put.
    await tester.enterText(find.byKey(SideChatView.questionFieldKey), "And the queue?");
    await tester.tap(find.text("Retry"));
    await settle(tester);
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text, "And the queue?");
  });

  testWidgets("a question sent over the earlier chats brings the thread back", (tester) async {
    await pumpView(tester);
    await tester.tap(find.byKey(SideChatView.earlierButtonKey));
    await settle(tester);
    expect(find.text("Earlier side chats"), findsOneWidget);

    await ask(tester, "Where is the cache?");

    expect(find.text("Earlier side chats"), findsNothing);
    expect(find.text("Where is the cache?"), findsOneWidget);
    answer.complete(ApiResponse.success(const AskSideQuestionResponse.refused(reason: SideQuestionRefusal.noAnswer)));
    await settle(tester);
  });

  testWidgets("a repeated running reply is named and offers Retry", (tester) async {
    await pumpView(tester);
    await ask(tester, "Where is the cache?");

    answer.complete(
      ApiResponse.success(const AskSideQuestionResponse.refused(reason: SideQuestionRefusal.repeatedRunningReply)),
    );
    await settle(tester);

    expect(find.text("Couldn't answer while Claude Code was busy. Ask again."), findsOneWidget);
    expect(find.text("Retry"), findsOneWidget);
  });

  testWidgets("a chat too long to continue offers no Retry", (tester) async {
    await pumpView(tester);
    await ask(tester, "Where is the cache?");

    answer.complete(ApiResponse.success(const AskSideQuestionResponse.refused(reason: SideQuestionRefusal.tooLong)));
    await settle(tester);

    expect(find.text("This side chat is too long to continue. Start a new one."), findsOneWidget);
    expect(find.text("Retry"), findsNothing);
  });

  testWidgets("an earlier chat reopens under its first question", (tester) async {
    await pumpView(tester);

    await tester.tap(find.byKey(SideChatView.earlierButtonKey));
    await settle(tester);
    expect(find.text("Earlier side chats"), findsOneWidget);
    expect(find.text("1 question"), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey("chat-earlier")));
    await settle(tester);

    expect(find.text("Earlier side chats"), findsNothing);
    expect(find.text("The lexer file."), findsOneWidget);
    expect(find.text("Which file holds the parser?"), findsNWidgets(2), reason: "the title and its bubble");
    expect(find.byKey(SideChatView.newChatButtonKey), findsOneWidget);
  });

  testWidgets("an archived session opens on its newest chat, read-only", (tester) async {
    await pumpView(tester, isArchived: true);

    expect(find.text("It backs off twice."), findsOneWidget);
    expect(find.text("What does the retry do?"), findsNWidgets(2), reason: "the title and its bubble");
    expect(find.text("This session is archived. Its side chats are read-only."), findsOneWidget);
    expect(find.byKey(SideChatView.questionFieldKey), findsNothing);
    expect(find.byKey(SideChatView.newChatButtonKey), findsNothing);
  });

  testWidgets(
    "a trackpad overscroll stretches steadily while a copy button slides under a resting cursor",
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    (tester) async {
      when(() => repository.listSideChats(sessionId: any(named: "sessionId"))).thenAnswer(
        (_) async => ApiResponse.success(
          SideChatListResponse(
            sideChats: [
              SideChat(
                id: "chat-long",
                exchanges: [
                  for (var index = 0; index < 6; index++)
                    _exchange(id: "l$index", question: "Question $index", answer: "Fixture text\n\n" * 4),
                ],
              ),
            ],
          ),
        ),
      );
      // An archived session opens straight on its newest chat.
      await pumpView(tester, isArchived: true);
      await expectSteadyTrackpadOverscroll(tester: tester, target: find.byType(PregoCopyIconButton).last);
    },
  );
}
