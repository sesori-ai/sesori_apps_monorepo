import "dart:convert";

import "package:sesori_bridge/src/repositories/models/session_page_cursor.dart";
import "package:sesori_bridge/src/routing/get_session_page_handler.dart";
import "package:sesori_bridge/src/services/session_view_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  late FakeBridgePlugin plugin;
  late FakeSessionRepository sessionRepository;
  late GetSessionPageHandler handler;

  setUp(() {
    plugin = FakeBridgePlugin();
    sessionRepository = FakeSessionRepository(plugin: plugin);
    handler = GetSessionPageHandler(sessionRepository: sessionRepository, sessionViews: const _TitlingSessionViews());
  });

  tearDown(() => plugin.close());

  Future<RelayResponse> post({required Map<String, Object?> body}) =>
      handler.routeForTest(makeRequest("POST", "/sessions/page", body: jsonEncode(body)));

  Map<String, Object?> request({
    String? projectId,
    String? query,
    String? cursor,
    int limit = 200,
  }) => {
    "mode": "active",
    "projectId": ?projectId,
    "query": ?query,
    "filter": "running",
    "cursor": ?cursor,
    "limit": limit,
  };

  test("handles POST /sessions/page only", () {
    expect(handler.canHandle(makeRequest("POST", "/sessions/page")), isTrue);
    expect(handler.canHandle(makeRequest("POST", "/sessions")), isFalse);
  });

  test("passes the request on, enriches the items and encodes the next cursor", () async {
    const next = SessionPageCursor(sortAt: 42, sessionId: "ses_b");
    sessionRepository.sessionPage = (
      items: [_session(id: "ses_a")],
      nextCursor: next,
      counts: const SessionPageCounts(all: 3, running: 1, unread: 2),
    );
    const previous = SessionPageCursor(sortAt: 50, sessionId: "ses:z");

    final response = await post(
      body: request(projectId: "/work/app", query: "fix it", cursor: previous.encode()),
    );

    expect(response.status, 200);
    final args = sessionRepository.lastSessionPageArgs;
    expect(args?.mode, SessionPageMode.active);
    expect(args?.projectId, "/work/app");
    expect(args?.query, "fix it");
    expect(args?.filter, SessionPageFilter.running);
    expect(args?.cursor?.sortAt, 50);
    expect(args?.cursor?.sessionId, "ses:z");
    expect(args?.limit, 200);
    final page = SessionPageResponse.fromJson(jsonDecode(response.body ?? "") as Map<String, dynamic>);
    expect(page.items.single.title, "enriched");
    expect(page.counts, const SessionPageCounts(all: 3, running: 1, unread: 2));
    final parsed = SessionPageCursor.tryParse(encoded: page.nextCursor ?? "");
    expect((parsed?.sortAt, parsed?.sessionId), (42, "ses_b"));
  });

  test("omits null fields from the JSON", () async {
    final response = await post(body: request(limit: 0));

    final json = jsonDecode(response.body ?? "") as Map<String, dynamic>;
    expect(json, {
      "items": <Object?>[],
      "counts": {"all": 0, "running": 0, "unread": 0},
    });
    expect(
      const SessionPageRequest(
        mode: SessionPageMode.archived,
        projectId: null,
        query: null,
        filter: SessionPageFilter.all,
        cursor: null,
        limit: 0,
      ).toJson(),
      {"mode": "archived", "filter": "all", "limit": 0},
    );
  });

  test("accepts limits from 0 to 1000", () async {
    expect((await post(body: request(limit: 0))).status, 200);
    expect((await post(body: request(limit: 1000))).status, 200);
  });

  for (final (name, body) in [
    ("a negative limit", {"limit": -1}),
    ("a limit above 1000", {"limit": 1001}),
    ("an invalid cursor", {"cursor": "not a cursor"}),
    ("a cursor without an id", {"cursor": base64Url.encode(utf8.encode("12:"))}),
    ("a blank query", {"query": "  "}),
    ("an empty project id", {"projectId": ""}),
    ("an unknown filter", {"filter": "pinned"}),
  ]) {
    test("answers 400 for $name", () async {
      final response = await post(body: {...request(), ...body});

      expect(response.status, 400);
      expect(sessionRepository.lastSessionPageArgs, isNull);
    });
  }
}

Session _session({required String id}) => Session(
  id: id,
  projectID: "/work/app",
  directory: "/work/app",
  parentID: null,
  title: "raw",
  time: null,
  promptDefaults: null,
  branchName: null,
  lastUserActivityAt: null,
  autoContinuation: null,
  approvalOverride: null,
);

final class const _TitlingSessionViews() implements SessionViewService {
  @override
  Future<List<Session>> enrichMany({required List<Session> sessions}) async => [
    for (final session in sessions) session.copyWith(title: "enriched"),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
