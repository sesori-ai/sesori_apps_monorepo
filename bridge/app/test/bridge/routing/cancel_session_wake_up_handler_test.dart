import "dart:convert";

import "package:sesori_bridge/src/routing/cancel_session_wake_up_handler.dart";
import "package:sesori_bridge/src/services/session_view_service.dart";
import "package:sesori_bridge/src/services/session_wake_up_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  late _WakeUps wakeUps;
  late CancelSessionWakeUpHandler handler;

  setUp(() {
    wakeUps = _WakeUps();
    handler = CancelSessionWakeUpHandler(wakeUps: wakeUps, sessionViews: const _Views());
  });

  Future<RelayResponse> cancel({required String sessionId, required String wakeUpId}) => handler.routeForTest(
    makeRequest(
      "POST",
      "/session/wake-up/cancel",
      body: jsonEncode(CancelSessionWakeUpRequest(sessionId: sessionId, wakeUpId: wakeUpId).toJson()),
    ),
  );

  test("cancels the wake-up and answers with the session as it is now", () async {
    final response = await cancel(sessionId: "s1", wakeUpId: "wakeup-1");

    expect(response.status, 200);
    expect(wakeUps.cancels, [("s1", "wakeup-1")]);
    expect(Session.fromJson(jsonDecodeMap(response.body ?? "")).id, "s1");
  });

  test("a wake-up already gone answers with the session too", () async {
    wakeUps.result = WakeUpCancelResult.notFound;

    expect((await cancel(sessionId: "s1", wakeUpId: "wakeup-gone")).status, 200);
  });

  test("an empty id is a bad request", () async {
    expect((await cancel(sessionId: "", wakeUpId: "wakeup-1")).status, 400);
    expect((await cancel(sessionId: "s1", wakeUpId: "")).status, 400);
    expect(wakeUps.cancels, isEmpty);
  });
}

class _WakeUps() implements SessionWakeUpService {
  final List<(String, String)> cancels = [];
  WakeUpCancelResult result = WakeUpCancelResult.cancelled;

  @override
  Future<WakeUpCancelResult> cancel({required String sessionId, required String wakeUpId}) async {
    cancels.add((sessionId, wakeUpId));
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class const _Views() implements SessionViewService {
  @override
  Future<Session> get({required String sessionId}) async => Session(
    approvalOverride: null,
    autoContinuation: null,
    branchName: null,
    id: sessionId,
    pluginId: "fake",
    projectID: "/repo",
    directory: "/repo",
    parentID: null,
    forkedFrom: null,
    title: null,
    time: null,
    promptDefaults: null,
    lastUserActivityAt: null,
    pinOrder: null,
    scheduledTask: null,
    interruption: null,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
