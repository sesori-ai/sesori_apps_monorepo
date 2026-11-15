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
            child: SideChatView(scrollController: scrollController, harnessName: "Claude Code", onClose: () {}),
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
}
