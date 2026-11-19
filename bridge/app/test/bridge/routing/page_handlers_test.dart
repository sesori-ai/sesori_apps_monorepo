import "dart:convert";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/agent_page_repository.dart";
import "package:sesori_bridge/src/repositories/models/agent_page.dart";
import "package:sesori_bridge/src/routing/lookup_page_handler.dart";
import "package:sesori_bridge/src/routing/submit_page_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/agent_page_test_support.dart";
import "../../helpers/test_database.dart";
import "routing_test_helpers.dart";

const _sections = [
  PageSection(
    heading: null,
    body: null,
    images: [],
    questions: [
      PageQuestion(
        id: "palette",
        title: "Palette",
        body: null,
        images: [],
        kind: PageQuestionKind.single(
          options: [
            PageOption(id: "warm", label: "Warm", description: null, image: null, recommended: false),
            PageOption(id: "cool", label: "Cool", description: null, image: null, recommended: true),
          ],
        ),
        isRequired: true,
      ),
      PageQuestion(
        id: "screens",
        title: "Screens",
        body: null,
        images: [],
        // Shares option ids with "palette": they are unique only within their question.
        kind: PageQuestionKind.multiple(
          options: [
            PageOption(id: "home", label: "Home", description: null, image: null, recommended: false),
            PageOption(id: "warm", label: "Settings", description: null, image: null, recommended: false),
          ],
        ),
        isRequired: false,
      ),
      PageQuestion(
        id: "name",
        title: "Name",
        body: null,
        images: [],
        kind: PageQuestionKind.text(),
        isRequired: false,
      ),
    ],
  ),
];

const _palette = PageAnswer(
  questionId: "palette",
  value: PageAnswerValue.choice(optionId: "cool"),
  note: null,
);

void main() {
  late FakeBridgePlugin plugin;
  late AppDatabase db;
  late AgentPageRepository pages;
  late RecordingSessionNotices notices;
  late LookupPageHandler lookup;
  late SubmitPageHandler submit;

  setUp(() async {
    plugin = FakeBridgePlugin();
    db = createTestDatabase();
    addTearDown(db.close);
    for (final (sessionId, parent) in [("ses-1", null), ("ses-child", "ses-1"), ("ses-other", null)]) {
      await recordSessionBinding(
        database: db,
        sessionId: sessionId,
        backendSessionId: "backend-$sessionId",
        pluginId: plugin.id,
        projectId: "/repo",
        parentSessionId: parent,
      );
    }
    final agentPages = buildTestAgentPages(database: db, plugin: plugin);
    pages = agentPages.pages;
    notices = agentPages.notices;
    addTearDown(pages.dispose);
    lookup = LookupPageHandler(agentPageService: agentPages.service);
    submit = SubmitPageHandler(agentPageService: agentPages.service);
  });

  tearDown(() => plugin.close());

  Future<PendingPage> addPage({String sessionId = "ses-1", String? displaySessionId}) => pages.add(
    sessionId: sessionId,
    displaySessionId: displaySessionId,
    title: "Design pass",
    intro: null,
    sections: _sections,
  );

  Future<PageLookupResponse> look({required String sessionId, required String requestId}) => lookup.handle(
    request: makeRequest("POST", "/page"),
    body: PageLookupRequest(sessionId: sessionId, requestId: requestId),
  );

  SubmitPageRequest submission({
    required String requestId,
    String sessionId = "ses-1",
    List<PageAnswer> answers = const [_palette],
    String? note,
  }) => SubmitPageRequest(requestId: requestId, sessionId: sessionId, answers: answers, note: note);

  Future<PageSubmitResult> send(SubmitPageRequest body) =>
      submit.handle(request: makeRequest("POST", "/page/submit"), body: body);

  group("LookupPageHandler", () {
    test("opens a pending page", () async {
      final page = await addPage();

      expect(await look(sessionId: "ses-1", requestId: page.id), PageLookupResponse.pending(page: page));
    });

    test("opens an answered page with its answers and note", () async {
      final page = await addPage();
      await pages.settle(
        id: page.id,
        outcome: const AgentPageAnswered(answers: [_palette], note: "Thanks"),
      );

      expect(
        await look(sessionId: "ses-1", requestId: page.id),
        PageLookupResponse.answered(page: page, answers: const [_palette], note: "Thanks"),
      );
    });

    test("opens a dismissed page", () async {
      final page = await addPage();
      await pages.settle(id: page.id, outcome: const AgentPageDismissed());

      expect(await look(sessionId: "ses-1", requestId: page.id), PageLookupResponse.dismissed(page: page));
    });

    test("a sub-agent's page opens from its own session and from the root", () async {
      final page = await addPage(sessionId: "ses-child", displaySessionId: "ses-1");

      expect(await look(sessionId: "ses-child", requestId: page.id), isA<PageLookupPending>());
      expect(await look(sessionId: "ses-1", requestId: page.id), isA<PageLookupPending>());
    });

    test("an unknown id or another session's page is missing", () async {
      final page = await addPage();

      expect(await look(sessionId: "ses-1", requestId: "sesori-page-unknown"), const PageLookupResponse.missing());
      expect(await look(sessionId: "ses-other", requestId: page.id), const PageLookupResponse.missing());
    });

    test("an archived session's pending page is missing; a settled one keeps its outcome", () async {
      final pending = await addPage();
      final answered = await addPage();
      await pages.settle(
        id: answered.id,
        outcome: const AgentPageAnswered(answers: [_palette], note: null),
      );
      await db.sessionDao.setArchived(sessionId: "ses-1", archivedAt: 7, updatedAt: 7, projectionUpdatedAt: 7);

      expect(await look(sessionId: "ses-1", requestId: pending.id), const PageLookupResponse.missing());
      expect(
        await look(sessionId: "ses-1", requestId: answered.id),
        PageLookupResponse.answered(page: answered, answers: const [_palette], note: null),
      );
    });
  });

  group("SubmitPageHandler", () {
    test("accepts the answers, settles the page and tells the root session with its reference", () async {
      final page = await addPage(sessionId: "ses-child", displaySessionId: "ses-1");
      const answers = [
        _palette,
        PageAnswer(
          questionId: "screens",
          value: PageAnswerValue.choices(optionIds: ["home", "warm"]),
          note: null,
        ),
        PageAnswer(questionId: "name", value: null, note: "Pick one for me"),
      ];

      final result = await send(submission(requestId: page.id, answers: answers, note: "Ship it"));

      expect(result, const PageSubmitResult.accepted());
      expect(
        await look(sessionId: "ses-1", requestId: page.id),
        PageLookupResponse.answered(page: page, answers: answers, note: "Ship it"),
      );
      final [delivered] = notices.delivered;
      expect(delivered.sessionId, "ses-1");
      expect(delivered.notice.summary, "You answered “Design pass”.");
      expect(delivered.notice.pageRequestId, page.id);
    });

    test("the first submit wins; later ones are already settled and tell nobody", () async {
      final page = await addPage();
      await send(submission(requestId: page.id));

      expect(await send(submission(requestId: page.id)), const PageSubmitResult.alreadySettled());
      expect(notices.delivered, hasLength(1));
    });

    test("a dismissed page is already settled", () async {
      final page = await addPage();
      await pages.settle(id: page.id, outcome: const AgentPageDismissed());

      expect(await send(submission(requestId: page.id)), const PageSubmitResult.alreadySettled());
    });

    group("refuses invalid answers, naming the questions, and leaves the page pending", () {
      final cases = <String, (List<PageAnswer>, List<String>)>{
        "a required question unanswered": (const [], ["palette"]),
        "a required question with only a note": (
          const [PageAnswer(questionId: "palette", value: null, note: "Not sure")],
          ["palette"],
        ),
        "an option of another question": (
          const [
            _palette,
            PageAnswer(
              questionId: "screens",
              value: PageAnswerValue.choices(optionIds: ["cool"]),
              note: null,
            ),
          ],
          ["screens"],
        ),
        "an unknown option": (
          const [
            PageAnswer(
              questionId: "palette",
              value: PageAnswerValue.choice(optionId: "neon"),
              note: null,
            ),
          ],
          ["palette"],
        ),
        "a value of another kind": (
          const [
            _palette,
            PageAnswer(
              questionId: "name",
              value: PageAnswerValue.choice(optionId: "warm"),
              note: null,
            ),
          ],
          ["name"],
        ),
        "an unknown question": (
          const [
            _palette,
            PageAnswer(
              questionId: "ghost",
              value: PageAnswerValue.text(text: "Boo"),
              note: null,
            ),
          ],
          ["ghost"],
        ),
        "a question answered twice": (const [_palette, _palette], ["palette"]),
      };
      for (final MapEntry(key: name, value: (answers, questionIds)) in cases.entries) {
        test(name, () async {
          final page = await addPage();

          expect(
            await send(submission(requestId: page.id, answers: answers)),
            PageSubmitResult.invalid(questionIds: questionIds),
          );
          expect(await look(sessionId: "ses-1", requestId: page.id), isA<PageLookupPending>());
          expect(notices.delivered, isEmpty);
        });
      }
    });

    test("refuses an archived session's page with 409", () async {
      final page = await addPage();
      await db.sessionDao.setArchived(sessionId: "ses-1", archivedAt: 7, updatedAt: 7, projectionUpdatedAt: 7);

      final response = await submit.routeForTest(
        makeRequest("POST", "/page/submit", body: jsonEncode(submission(requestId: page.id).toJson())),
      );

      expect(response.status, 409);
      expect((await pages.find(id: page.id))?.outcome, isNull);
      expect(notices.delivered, isEmpty);
    });

    test("answers 404 for an unknown id or another session's page", () async {
      final page = await addPage();

      for (final body in [
        submission(requestId: "sesori-page-unknown"),
        submission(requestId: page.id, sessionId: "ses-other"),
      ]) {
        final response = await submit.routeForTest(
          makeRequest("POST", "/page/submit", body: jsonEncode(body.toJson())),
        );
        expect(response.status, 404);
      }
      expect(await look(sessionId: "ses-1", requestId: page.id), isA<PageLookupPending>());
    });
  });
}
