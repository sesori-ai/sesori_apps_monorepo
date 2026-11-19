import "dart:async";
import "dart:typed_data";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";
import "../../services/pending_page_service_test.dart" show answeredDraft, page, pageImage;

class _MockFilePreviewRepository() extends Mock implements FilePreviewRepository;

const _connected = ConnectionStatus.connected(
  config: ServerConnectionConfig(relayHost: "fixture", authToken: "fixture", bridgeId: "first"),
  health: HealthResponse(healthy: true, version: "1.14.2", filesystemAccessDegraded: false),
);
const _reconnecting = ConnectionStatus.reconnecting(
  config: ServerConnectionConfig(relayHost: "fixture", authToken: "fixture", bridgeId: "first"),
);

void main() {
  setUpAll(registerAllFallbackValues);
  late MockSessionRepository repository;
  late MockProductAnalyticsService analytics;
  late MockConnectionService connection;
  late _MockFilePreviewRepository previews;
  late PageDraftRepository drafts;
  late BehaviorSubject<ConnectionStatus> statuses;
  late StreamController<SseEvent> events;

  void lookupAnswers(PageLookupResponse response) => when(
    () => repository.lookupPage(request: any(named: "request")),
  ).thenAnswer((_) async => ApiResponse.success(response));

  void submitAnswers(PageSubmitResult result) => when(
    () => repository.submitPage(request: any(named: "request")),
  ).thenAnswer((_) async => ApiResponse.success(result));

  setUp(() {
    registerFallbackValue(const SubmitPageRequest(requestId: "r", sessionId: "s", answers: [], note: null));
    registerFallbackValue(const PageLookupRequest(sessionId: "s", requestId: "r"));
    repository = MockSessionRepository();
    analytics = stubbedProductAnalyticsService();
    connection = MockConnectionService();
    previews = _MockFilePreviewRepository();
    drafts = PageDraftRepository();
    statuses = BehaviorSubject.seeded(_connected);
    events = StreamController<SseEvent>.broadcast();
    when(() => connection.status).thenAnswer((_) => statuses);
    when(() => connection.events).thenAnswer((_) => events.stream);
    lookupAnswers(const PageLookupResponse.pending(page: page));
    addTearDown(statuses.close);
    addTearDown(events.close);
  });

  PendingPageCubit create() {
    final cubit = PendingPageCubit(
      service: PendingPageService(repository: repository, productAnalyticsService: analytics),
      drafts: drafts,
      filePreviews: previews,
      connectionService: connection,
      requestId: page.id,
      sessionId: "root",
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Future<S> until<S extends PendingPageState>(PendingPageCubit cubit) async =>
      await awaitState(cubit: cubit, predicate: (state) => state is S, description: "$S") as S;

  Future<PageEditing> editing(PendingPageCubit cubit) => until<PageEditing>(cubit);

  void answerAll(PendingPageCubit cubit) {
    cubit
      ..setChoice(questionId: "plan", optionId: "a")
      ..setText(questionId: "why", text: "Faster")
      ..setNote(note: "Thanks");
  }

  int reportedEvents() {
    try {
      return verify(
        () => analytics.logEvent(
          event: any(named: "event"),
          occurredAtUtc: any(named: "occurredAtUtc"),
        ),
      ).callCount;
    } on TestFailure {
      return 0;
    }
  }

  test("a pending page opens for editing under the asked session, and its draft survives a close", () async {
    final first = create();
    expect((await editing(first)).draft.answers, isEmpty);
    verify(
      () => repository.lookupPage(
        request: PageLookupRequest(sessionId: "root", requestId: page.id),
      ),
    ).called(1);

    first
      ..setChoice(questionId: "plan", optionId: "b")
      ..setChoices(questionId: "extras", optionIds: ["x", "y"])
      ..setQuestionNote(questionId: "extras", note: "Both")
      ..setNote(note: "Later");
    await first.close();

    final reopened = await editing(create());
    expect(reopened.draft.answers, {
      "plan": const PageAnswer(
        questionId: "plan",
        value: PageChoiceAnswer(optionId: "b"),
        note: null,
      ),
      "extras": const PageAnswer(
        questionId: "extras",
        value: PageChoicesAnswer(optionIds: ["x", "y"]),
        note: "Both",
      ),
    });
    expect(reopened.draft.note, "Later");
  });

  test("clearing every pick and blank text leaves no answer behind", () async {
    final cubit = create();
    await editing(cubit);
    cubit
      ..setChoice(questionId: "plan", optionId: "a")
      ..setChoice(questionId: "plan", optionId: null)
      ..setText(questionId: "why", text: "   ")
      ..setNote(note: "");
    final state = cubit.state as PageEditing;
    expect(state.draft.answers, isEmpty);
    expect(state.draft.note, isNull);
  });

  test("an accepted submit is sent with its answers, drops the draft and reports once", () async {
    submitAnswers(const PageSubmitResult.accepted());
    final cubit = create();
    await editing(cubit);
    answerAll(cubit);
    final submitting = cubit.submit();
    expect(cubit.state, isA<PageSubmitting>().having((s) => s.action, "action", PageAction.submit));
    await submitting;

    final state = cubit.state as PageSettledHere;
    expect(state.action, PageAction.submit);
    expect(state.draft.note, "Thanks");
    expect(drafts.get(requestId: page.id), isNull);
    expect(reportedEvents(), 1);
  });

  test("an already settled submit keeps the local picks read-only as answered elsewhere", () async {
    submitAnswers(const PageSubmitResult.alreadySettled());
    final cubit = create();
    await editing(cubit);
    answerAll(cubit);
    await cubit.submit();

    final state = cubit.state as PageReadOnly;
    expect(state.reason, PageReadOnlyReason.answeredElsewhere);
    expect(state.draft.answers.keys, unorderedEquals(["plan", "why"]));
    expect(drafts.get(requestId: page.id), isNull);
    expect(reportedEvents(), 0);
  });

  test("unanswered required questions stay editable with the reason, which an answer clears", () async {
    final cubit = create();
    await editing(cubit);
    cubit.setChoice(questionId: "plan", optionId: "a");
    await cubit.submit();
    var state = cubit.state as PageEditing;
    expect((state.feedback as PageFeedbackInvalid).questionIds, ["why"]);
    verifyNever(() => repository.submitPage(request: any(named: "request")));

    cubit.setText(questionId: "why", text: "Faster");
    state = cubit.state as PageEditing;
    expect(state.feedback, isA<PageFeedbackNone>());
  });

  test("the bridge refusing answers keeps the draft editable with its question ids", () async {
    submitAnswers(const PageSubmitResult.invalid(questionIds: ["plan"]));
    final cubit = create();
    await editing(cubit);
    answerAll(cubit);
    await cubit.submit();
    final state = cubit.state as PageEditing;
    expect((state.feedback as PageFeedbackInvalid).questionIds, ["plan"]);
    expect(drafts.get(requestId: page.id), isNotNull);
    expect(reportedEvents(), 0);
  });

  test("a failed submit keeps the draft editable with the failure", () async {
    when(() => repository.submitPage(request: any(named: "request")))
        .thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
    final cubit = create();
    await editing(cubit);
    answerAll(cubit);
    await cubit.submit();
    final state = cubit.state as PageEditing;
    expect(state.feedback, isA<PageFeedbackFailed>().having((f) => f.action, "action", PageAction.submit));
    expect(state.draft.note, "Thanks");
  });

  test("a failed submit looks again and catches the page settling meanwhile", () async {
    when(() => repository.submitPage(request: any(named: "request")))
        .thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
    final cubit = create();
    await editing(cubit);
    answerAll(cubit);
    lookupAnswers(const PageLookupResponse.answered(page: page, answers: [], note: null));
    await cubit.submit();
    final state = cubit.state as PageReadOnly;
    expect(state.reason, PageReadOnlyReason.answeredElsewhere);
    expect(state.draft.note, "Thanks");
    expect(reportedEvents(), 0);
  });

  test("a confirmed dismiss settles here, drops the draft and reports once; a failed one stays editable", () async {
    when(() => repository.rejectQuestion(requestId: page.id, sessionId: "owner"))
        .thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
    final cubit = create();
    await editing(cubit);
    await cubit.dismiss();
    expect(
      (cubit.state as PageEditing).feedback,
      isA<PageFeedbackFailed>().having((f) => f.action, "action", PageAction.dismiss),
    );
    expect(reportedEvents(), 0);

    when(() => repository.rejectQuestion(requestId: page.id, sessionId: "owner"))
        .thenAnswer((_) async => ApiResponse.success(null));
    await cubit.dismiss();
    expect(cubit.state, isA<PageSettledHere>().having((s) => s.action, "action", PageAction.dismiss));
    expect(drafts.get(requestId: page.id), isNull);
    expect(reportedEvents(), 1);
  });

  test("a dismiss the bridge refuses for a page settled elsewhere turns read-only without the failure", () async {
    when(() => repository.rejectQuestion(requestId: page.id, sessionId: "owner"))
        .thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
    final cubit = create();
    await editing(cubit);
    lookupAnswers(const PageLookupResponse.dismissed(page: page));
    final states = <PendingPageState>[];
    final sub = cubit.stream.listen(states.add);
    await cubit.dismiss();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(states, [isA<PageSubmitting>(), isA<PageReadOnly>()]);
    expect((cubit.state as PageReadOnly).reason, PageReadOnlyReason.dismissed);
  });

  group("a page archived while open is refused with 409, then missing, without the failure", () {
    final archived = ApiError.nonSuccessCode(errorCode: 409, rawErrorString: null);

    Future<List<PendingPageState>> act({required Future<void> Function(PendingPageCubit cubit) action}) async {
      final cubit = create();
      await editing(cubit);
      answerAll(cubit);
      lookupAnswers(const PageLookupResponse.missing());
      final states = <PendingPageState>[];
      final sub = cubit.stream.listen(states.add);
      await action(cubit);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(drafts.get(requestId: page.id), isNull);
      expect(reportedEvents(), 0);
      return states;
    }

    test("on submit", () async {
      when(
        () => repository.submitPage(request: any(named: "request")),
      ).thenAnswer((_) async => ApiResponse.error(archived));

      expect(await act(action: (cubit) => cubit.submit()), [isA<PageSubmitting>(), isA<PageMissing>()]);
    });

    test("on dismiss", () async {
      when(
        () => repository.rejectQuestion(requestId: page.id, sessionId: "owner"),
      ).thenAnswer((_) async => ApiResponse.error(archived));

      expect(await act(action: (cubit) => cubit.dismiss()), [isA<PageSubmitting>(), isA<PageMissing>()]);
    });
  });

  test("an answered page opens read-only with its answers filled in", () async {
    drafts.save(
      requestId: page.id,
      draft: PageDraft.empty.withNote(note: "stale"),
    );
    lookupAnswers(
      const PageLookupResponse.answered(
        page: page,
        answers: [
          PageAnswer(
            questionId: "why",
            value: PageTextAnswer(text: "Faster"),
            note: "Sure",
          ),
        ],
        note: "Thanks",
      ),
    );
    final state = await until<PageReadOnly>(create());
    expect(state.reason, PageReadOnlyReason.answered);
    expect(state.draft.answers["why"]?.value, const PageTextAnswer(text: "Faster"));
    expect(state.draft.note, "Thanks");
    expect(drafts.get(requestId: page.id), isNull);
  });

  test("a dismissed page opens read-only with nothing filled in", () async {
    lookupAnswers(const PageLookupResponse.dismissed(page: page));
    final state = await until<PageReadOnly>(create());
    expect(state.reason, PageReadOnlyReason.dismissed);
    expect(state.draft.answers, isEmpty);
  });

  test("a missing page has a state of its own and drops its draft", () async {
    drafts.save(requestId: page.id, draft: answeredDraft);
    lookupAnswers(const PageLookupResponse.missing());
    await until<PageMissing>(create());
    expect(drafts.get(requestId: page.id), isNull);
  });

  test("a lookup shape this app doesn't know is unsupported", () async {
    lookupAnswers(const PageLookupResponse.unknown());
    await until<PageUnsupported>(create());
  });

  test("a failed open shows the failure and retries", () async {
    when(() => repository.lookupPage(request: any(named: "request")))
        .thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
    final cubit = create();
    await until<PageLoadFailed>(cubit);
    lookupAnswers(const PageLookupResponse.pending(page: page));
    await cubit.retry();
    expect(cubit.state, isA<PageEditing>());
  });

  for (final (event, reason) in [
    (
      SesoriSseEvent.questionReplied(requestID: page.id, sessionID: "owner", displaySessionId: "root"),
      PageReadOnlyReason.answeredElsewhere,
    ),
    (
      SesoriSseEvent.questionRejected(requestID: page.id, sessionID: "owner", displaySessionId: "root"),
      PageReadOnlyReason.dismissed,
    ),
  ]) {
    test("settling elsewhere while open turns read-only as ${reason.name} and keeps the local picks", () async {
      final cubit = create();
      await editing(cubit);
      cubit.setChoice(questionId: "plan", optionId: "a");
      events
        ..add(
          SseEvent(
            data: const SesoriSseEvent.questionReplied(requestID: "other", sessionID: "owner", displaySessionId: null),
          ),
        )
        ..add(SseEvent(data: event));
      final state = await until<PageReadOnly>(cubit);
      expect(state.reason, reason);
      expect(state.draft.answers["plan"]?.value, const PageChoiceAnswer(optionId: "a"));
      expect(drafts.get(requestId: page.id), isNull);
      cubit.setChoice(questionId: "plan", optionId: "b");
      expect(cubit.state, same(state));
    });
  }

  test("its own settlement event during a submit leaves the outcome to the bridge's answer", () async {
    final answer = Completer<ApiResponse<PageSubmitResult>>();
    when(() => repository.submitPage(request: any(named: "request"))).thenAnswer((_) => answer.future);
    final cubit = create();
    await editing(cubit);
    answerAll(cubit);
    final submitting = cubit.submit();
    events.add(
      SseEvent(
        data: SesoriSseEvent.questionReplied(requestID: page.id, sessionID: "owner", displaySessionId: "root"),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, isA<PageSubmitting>());
    answer.complete(ApiResponse.success(const PageSubmitResult.accepted()));
    await submitting;
    expect(cubit.state, isA<PageSettledHere>());
  });

  test("a reconnect looks the open page up again and catches a settlement it missed", () async {
    final cubit = create();
    await editing(cubit);
    cubit.setChoice(questionId: "plan", optionId: "b");
    lookupAnswers(const PageLookupResponse.answered(page: page, answers: [], note: null));
    statuses
      ..add(_reconnecting)
      ..add(_connected);
    final state = await until<PageReadOnly>(cubit);
    expect(state.reason, PageReadOnlyReason.answeredElsewhere);
    expect(state.draft.answers["plan"]?.value, const PageChoiceAnswer(optionId: "b"));
  });

  test("a reconnect that finds the page still pending keeps the edits", () async {
    final cubit = create();
    await editing(cubit);
    cubit.setChoice(questionId: "plan", optionId: "b");
    connection.emitDataMayBeStale();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    verify(() => repository.lookupPage(request: any(named: "request"))).called(2);
    expect((cubit.state as PageEditing).draft.answers["plan"]?.value, const PageChoiceAnswer(optionId: "b"));
  });

  test("images load once while open, and a failed read may load again", () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    var reads = 0;
    when(() => previews.load(path: pageImage.path)).thenAnswer((_) async {
      reads++;
      return reads == 1
          ? FilePreviewFailed(innerError: StateError("offline"), stackTrace: StackTrace.current)
          : FilePreviewImageContent(bytes: bytes, mime: "image/png");
    });
    final cubit = create();
    expect(await cubit.loadImage(image: pageImage), isNull);
    expect(await cubit.loadImage(image: pageImage), bytes);
    expect(await cubit.loadImage(image: pageImage), bytes);
    expect(reads, 2);
  });
}
