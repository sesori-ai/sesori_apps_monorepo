import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

class _MockSideChatRepository() extends Mock implements SideChatRepository;

SideChatExchange _exchange({required String id, required int answeredAt}) => SideChatExchange(
  id: id,
  question: "question $id",
  answer: "answer $id",
  answerNotice: null,
  askedAt: answeredAt - 1,
  answeredAt: answeredAt,
);

final _olderChat = SideChat(
  id: "chat-old",
  exchanges: [_exchange(id: "o1", answeredAt: 100)],
);
final _newerChat = SideChat(
  id: "chat-new",
  exchanges: [_exchange(id: "n1", answeredAt: 200)],
);

void main() {
  late _MockSideChatRepository repository;
  late MockProductAnalyticsService productAnalyticsService;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    repository = _MockSideChatRepository();
    productAnalyticsService = stubbedProductAnalyticsService();
    when(
      () => repository.listSideChats(sessionId: any(named: "sessionId")),
    ).thenAnswer((_) async => ApiResponse.success(SideChatListResponse(sideChats: [_newerChat, _olderChat])));
  });

  SideChatCubit createCubit({
    String pluginId = "claude",
    SideQuestionAvailability availability = SideQuestionAvailability.available,
    bool isArchived = false,
    String? initialQuestion,
  }) {
    final cubit = SideChatCubit(
      repository: repository,
      productAnalyticsService: productAnalyticsService,
      sessionId: "session-1",
      pluginId: pluginId,
      availability: availability,
      isArchived: isArchived,
      initialQuestion: initialQuestion,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Future<SideChatReady> ready(SideChatCubit cubit) async {
    final state = cubit.state is SideChatReady
        ? cubit.state
        : await cubit.stream.firstWhere((state) => state is SideChatReady);
    return state as SideChatReady;
  }

  void answerAsk(Future<ApiResponse<AskSideQuestionResponse>> Function() answer) => when(
    () => repository.askSideQuestion(
      sessionId: any(named: "sessionId"),
      sideChatId: any(named: "sideChatId"),
      question: any(named: "question"),
    ),
  ).thenAnswer((_) => answer());

  List<ProductAnalyticsEvent> reportedEvents() => verify(
    () => productAnalyticsService.logEvent(
      event: captureAny(named: "event"),
      occurredAtUtc: any(named: "occurredAtUtc"),
    ),
  ).captured.cast<ProductAnalyticsEvent>();

  group("loading", () {
    test("opens on a new chat with the session's chats as earlier ones", () async {
      final cubit = createCubit();
      expect(cubit.state, const SideChatState.loading());

      final state = await ready(cubit);

      expect(state.thread, const SideChatThread.newChat());
      expect(state.earlierChats, [_newerChat, _olderChat]);
      expect(state.ask, const SideQuestionAsk.idle());
      verify(() => repository.listSideChats(sessionId: "session-1")).called(1);
    });

    test("a failed load offers reload, which loads again", () async {
      when(
        () => repository.listSideChats(sessionId: any(named: "sessionId")),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
      final cubit = createCubit();
      await cubit.stream.firstWhere((state) => state is SideChatLoadFailed);

      when(
        () => repository.listSideChats(sessionId: any(named: "sessionId")),
      ).thenAnswer((_) async => ApiResponse.success(const SideChatListResponse(sideChats: [])));
      final states = <SideChatState>[];
      final subscription = cubit.stream.listen(states.add);
      await cubit.reload();
      await subscription.cancel();

      expect(states.first, const SideChatState.loading());
      expect(cubit.state, isA<SideChatReady>().having((state) => state.earlierChats, "earlierChats", isEmpty));
    });
  });

  group("asking", () {
    test("an answer in a new chat makes it the shown chat, then follow-ups continue it", () async {
      final cubit = createCubit();
      await ready(cubit);
      final first = _exchange(id: "e1", answeredAt: 300);
      final answer = Completer<ApiResponse<AskSideQuestionResponse>>();
      answerAsk(() => answer.future);

      final asked = cubit.ask(text: "  why?  ");
      expect((cubit.state as SideChatReady).ask, const SideQuestionAsk.waiting(question: "why?"));
      answer.complete(ApiResponse.success(AskSideQuestionResponse.answered(sideChatId: "chat-1", exchange: first)));
      await asked;

      var state = cubit.state as SideChatReady;
      expect(state.ask, const SideQuestionAsk.idle());
      expect(
        state.thread,
        SideChatThread.existing(
          chat: SideChat(id: "chat-1", exchanges: [first]),
        ),
      );
      expect(state.earlierChats, [_newerChat, _olderChat]);
      verify(() => repository.askSideQuestion(sessionId: "session-1", sideChatId: null, question: "why?")).called(1);

      final second = _exchange(id: "e2", answeredAt: 400);
      answerAsk(
        () async => ApiResponse.success(AskSideQuestionResponse.answered(sideChatId: "chat-1", exchange: second)),
      );
      await cubit.ask(text: "and then?");

      state = cubit.state as SideChatReady;
      expect(
        state.thread,
        SideChatThread.existing(
          chat: SideChat(id: "chat-1", exchanges: [first, second]),
        ),
      );
      verify(
        () => repository.askSideQuestion(sessionId: "session-1", sideChatId: "chat-1", question: "and then?"),
      ).called(1);
    });

    test("only one question is asked at a time, and blank text asks nothing", () async {
      final cubit = createCubit();
      await ready(cubit);
      final answer = Completer<ApiResponse<AskSideQuestionResponse>>();
      answerAsk(() => answer.future);

      final asked = cubit.ask(text: "first");
      await cubit.ask(text: "second");
      await cubit.ask(text: "   ");
      answer.complete(
        ApiResponse.success(const AskSideQuestionResponse.refused(reason: SideQuestionRefusal.noTurnYet)),
      );
      await asked;

      verify(
        () => repository.askSideQuestion(
          sessionId: any(named: "sessionId"),
          sideChatId: any(named: "sideChatId"),
          question: any(named: "question"),
        ),
      ).called(1);
    });

    test("a refusal keeps the question for retry, which asks it again", () async {
      final cubit = createCubit();
      await ready(cubit);
      answerAsk(
        () async => ApiResponse.success(const AskSideQuestionResponse.refused(reason: SideQuestionRefusal.tooLong)),
      );

      await cubit.ask(text: "long one");

      expect(
        (cubit.state as SideChatReady).ask,
        const SideQuestionAsk.refused(question: "long one", reason: SideQuestionRefusal.tooLong),
      );

      final exchange = _exchange(id: "e1", answeredAt: 300);
      answerAsk(
        () async => ApiResponse.success(AskSideQuestionResponse.answered(sideChatId: "chat-1", exchange: exchange)),
      );
      await cubit.retry();

      expect((cubit.state as SideChatReady).ask, const SideQuestionAsk.idle());
      verify(() => repository.askSideQuestion(sessionId: "session-1", sideChatId: null, question: "long one"))
          .called(2);
    });

    test("a response kind from a newer bridge reads as an unknown refusal", () async {
      final cubit = createCubit();
      await ready(cubit);
      answerAsk(() async => ApiResponse.success(const AskSideQuestionResponse.unknown()));

      await cubit.ask(text: "why?");

      expect(
        (cubit.state as SideChatReady).ask,
        const SideQuestionAsk.refused(question: "why?", reason: SideQuestionRefusal.unknown),
      );
    });

    test("a failed request keeps the question for retry", () async {
      final cubit = createCubit();
      await ready(cubit);
      answerAsk(() async => ApiResponse.error(ApiError.generic()));

      await cubit.ask(text: "why?");

      expect((cubit.state as SideChatReady).ask, const SideQuestionAsk.failed(question: "why?"));
    });

    test("an initial question is asked in a new chat at once", () async {
      final exchange = _exchange(id: "e1", answeredAt: 300);
      final answer = Completer<ApiResponse<AskSideQuestionResponse>>();
      answerAsk(() => answer.future);
      final chats = Completer<ApiResponse<SideChatListResponse>>();
      when(() => repository.listSideChats(sessionId: any(named: "sessionId"))).thenAnswer((_) => chats.future);

      final cubit = createCubit(initialQuestion: "from btw");
      expect(
        cubit.state,
        const SideChatState.ready(
          earlierChats: [],
          thread: SideChatThread.newChat(),
          ask: SideQuestionAsk.waiting(question: "from btw"),
        ),
        reason: "the sheet opens on the question, not a spinner",
      );
      verify(() => repository.askSideQuestion(sessionId: "session-1", sideChatId: null, question: "from btw"))
          .called(1);

      answer.complete(ApiResponse.success(AskSideQuestionResponse.answered(sideChatId: "chat-1", exchange: exchange)));
      await cubit.stream.firstWhere((state) => state is SideChatReady && state.thread is SideChatExistingThread);
      final answered = SideChat(id: "chat-1", exchanges: [exchange]);
      chats.complete(ApiResponse.success(SideChatListResponse(sideChats: [answered, _newerChat, _olderChat])));
      await cubit.stream.firstWhere((state) => state is SideChatReady && state.earlierChats.isNotEmpty);

      final state = cubit.state as SideChatReady;
      expect(state.thread, SideChatThread.existing(chat: answered));
      expect(state.earlierChats, [_newerChat, _olderChat], reason: "the shown chat isn't also an earlier one");
    });

    test("an initial question stays on screen when the chats fail to load", () async {
      when(
        () => repository.listSideChats(sessionId: any(named: "sessionId")),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
      final answer = Completer<ApiResponse<AskSideQuestionResponse>>();
      answerAsk(() => answer.future);
      final cubit = createCubit(initialQuestion: "from btw");
      await pumpEventQueue();

      expect((cubit.state as SideChatReady).ask, const SideQuestionAsk.waiting(question: "from btw"));
      answer.complete(ApiResponse.error(ApiError.generic()));
      await pumpEventQueue();
      expect((cubit.state as SideChatReady).ask, const SideQuestionAsk.failed(question: "from btw"));
    });

    test("closing while waiting still reports the result and emits nothing", () async {
      final cubit = createCubit();
      await ready(cubit);
      final answer = Completer<ApiResponse<AskSideQuestionResponse>>();
      answerAsk(() => answer.future);

      final asked = cubit.ask(text: "why?");
      await cubit.close();
      answer.complete(
        ApiResponse.success(
          AskSideQuestionResponse.answered(
            sideChatId: "chat-1",
            exchange: _exchange(id: "e1", answeredAt: 300),
          ),
        ),
      );
      await asked;

      expect(reportedEvents(), [
        const ProductAnalyticsEvent.sideQuestionAsked(
          harness: AnalyticsHarness.claudeCode,
          outcome: AnalyticsSideQuestionOutcome.answered,
        ),
      ]);
    });
  });

  group("switching chats", () {
    test("opening an earlier chat shows it and returns the shown one to the list", () async {
      final cubit = createCubit();
      await ready(cubit);
      final exchange = _exchange(id: "e1", answeredAt: 300);
      answerAsk(
        () async => ApiResponse.success(AskSideQuestionResponse.answered(sideChatId: "chat-1", exchange: exchange)),
      );
      await cubit.ask(text: "why?");
      final asked = SideChat(id: "chat-1", exchanges: [exchange]);

      cubit.openChat(id: _olderChat.id);

      var state = cubit.state as SideChatReady;
      expect(state.thread, SideChatThread.existing(chat: _olderChat));
      expect(state.earlierChats, [asked, _newerChat]);

      cubit.startNewChat();

      state = cubit.state as SideChatReady;
      expect(state.thread, const SideChatThread.newChat());
      expect(state.earlierChats, [asked, _newerChat, _olderChat]);
    });

    test("switching clears a refusal, and an unknown chat id changes nothing", () async {
      final cubit = createCubit();
      await ready(cubit);
      answerAsk(() async => ApiResponse.error(ApiError.generic()));
      await cubit.ask(text: "why?");

      cubit.openChat(id: "missing");
      expect((cubit.state as SideChatReady).ask, const SideQuestionAsk.failed(question: "why?"));

      cubit.openChat(id: _newerChat.id);
      expect((cubit.state as SideChatReady).ask, const SideQuestionAsk.idle());
    });

    test("the shown chat doesn't change while a question waits", () async {
      final cubit = createCubit();
      await ready(cubit);
      final answer = Completer<ApiResponse<AskSideQuestionResponse>>();
      answerAsk(() => answer.future);

      final asked = cubit.ask(text: "why?");
      cubit.openChat(id: _olderChat.id);

      expect((cubit.state as SideChatReady).thread, const SideChatThread.newChat());
      answer.complete(ApiResponse.error(ApiError.generic()));
      await asked;
    });
  });

  group("read-only", () {
    test("an archived session opens on its newest chat and takes no questions", () async {
      final cubit = createCubit(isArchived: true);
      await ready(cubit);

      expect(
        cubit.state,
        SideChatState.ready(
          earlierChats: [_olderChat],
          thread: SideChatThread.existing(chat: _newerChat),
          ask: const SideQuestionAsk.idle(),
        ),
      );
      expect(cubit.canAsk, isFalse);
      await cubit.ask(text: "why?");

      cubit.openChat(id: _olderChat.id);
      expect((cubit.state as SideChatReady).thread, SideChatThread.existing(chat: _olderChat));
      verifyNever(
        () => repository.askSideQuestion(
          sessionId: any(named: "sessionId"),
          sideChatId: any(named: "sideChatId"),
          question: any(named: "question"),
        ),
      );
    });

    test("an initial question on an archived session is never asked", () async {
      final cubit = createCubit(isArchived: true, initialQuestion: "why?");
      await ready(cubit);
      await pumpEventQueue();

      verifyNever(
        () => repository.askSideQuestion(
          sessionId: any(named: "sessionId"),
          sideChatId: any(named: "sideChatId"),
          question: any(named: "question"),
        ),
      );
    });

    test("only an available, live session can ask", () {
      for (final availability in SideQuestionAvailability.values) {
        expect(
          createCubit(availability: availability).canAsk,
          availability == SideQuestionAvailability.available,
          reason: "$availability",
        );
      }
    });
  });

  group("analytics", () {
    test("each result reports its harness and bounded outcome", () async {
      final cases = <(ApiResponse<AskSideQuestionResponse>, AnalyticsSideQuestionOutcome)>[
        (
          ApiResponse.success(
            AskSideQuestionResponse.answered(
              sideChatId: "chat-1",
              exchange: _exchange(id: "e1", answeredAt: 300),
            ),
          ),
          AnalyticsSideQuestionOutcome.answered,
        ),
        (
          ApiResponse.success(const AskSideQuestionResponse.refused(reason: SideQuestionRefusal.noAnswer)),
          AnalyticsSideQuestionOutcome.noAnswer,
        ),
        for (final reason in [
          SideQuestionRefusal.harnessUnsupported,
          SideQuestionRefusal.harnessUpdateRequired,
          SideQuestionRefusal.noTurnYet,
          SideQuestionRefusal.tooLong,
          SideQuestionRefusal.unknown,
        ])
          (
            ApiResponse.success(AskSideQuestionResponse.refused(reason: reason)),
            AnalyticsSideQuestionOutcome.unavailable,
          ),
        (ApiResponse.success(const AskSideQuestionResponse.unknown()), AnalyticsSideQuestionOutcome.failed),
        (ApiResponse.error(ApiError.generic()), AnalyticsSideQuestionOutcome.failed),
      ];

      for (final (response, outcome) in cases) {
        final cubit = createCubit(pluginId: "codex");
        await ready(cubit);
        answerAsk(() async => response);

        await cubit.ask(text: "why?");

        expect(reportedEvents(), [
          ProductAnalyticsEvent.sideQuestionAsked(harness: AnalyticsHarness.codex, outcome: outcome),
        ], reason: "$outcome");
      }
    });

    test("nothing is reported for asks that never reach the bridge", () async {
      final cubit = createCubit(isArchived: true);
      await ready(cubit);

      await cubit.ask(text: "why?");

      verifyNever(
        () => productAnalyticsService.logEvent(
          event: any(named: "event"),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      );
    });
  });
}
