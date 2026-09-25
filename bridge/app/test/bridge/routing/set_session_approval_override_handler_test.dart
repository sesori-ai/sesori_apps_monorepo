import "dart:convert";

import "package:sesori_bridge/src/routing/set_session_approval_override_handler.dart";
import "package:sesori_bridge/src/services/session_view_service.dart";
import "package:sesori_bridge/src/services/yolo_settings_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginOperationException;
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("SetSessionApprovalOverrideHandler", () {
    late _FakeYoloSettingsService yoloSettingsService;
    late SetSessionApprovalOverrideHandler handler;

    setUp(() {
      yoloSettingsService = _FakeYoloSettingsService();
      handler = SetSessionApprovalOverrideHandler(
        yoloSettingsService: yoloSettingsService,
        sessionViews: _FakeSessionViewService(),
      );
    });

    String body({required SessionApprovalMode? approvalOverride}) => jsonEncode(
      SetSessionApprovalOverrideRequest(sessionId: "session-1", approvalOverride: approvalOverride),
    );

    test("canHandle accepts only PATCH /session/approval-override", () {
      expect(handler.canHandle(makeRequest("PATCH", "/session/approval-override")), isTrue);
      expect(handler.canHandle(makeRequest("POST", "/session/approval-override")), isFalse);
      expect(handler.canHandle(makeRequest("PATCH", "/session/auto-continuation")), isFalse);
    });

    test("sets the override and returns the enriched session", () async {
      final response = await handler.routeForTest(
        makeRequest("PATCH", "/session/approval-override", body: body(approvalOverride: SessionApprovalMode.yolo)),
      );

      expect(response.status, 200);
      final session = Session.fromJson(jsonDecodeMap(response.body ?? ""));
      expect(session.approvalOverride, SessionApprovalMode.yolo);
      expect(session.title, "enriched");
      expect(yoloSettingsService.calls, [(sessionId: "session-1", approvalOverride: SessionApprovalMode.yolo)]);
    });

    test("a null override clears it", () async {
      final response = await handler.routeForTest(
        makeRequest("PATCH", "/session/approval-override", body: body(approvalOverride: null)),
      );

      expect(response.status, 200);
      expect(Session.fromJson(jsonDecodeMap(response.body ?? "")).approvalOverride, isNull);
      expect(yoloSettingsService.calls.single.approvalOverride, isNull);
    });

    test("a missing session is a 404 with a body, unlike an unknown route", () async {
      yoloSettingsService.error = const PluginOperationException.notFound("setApprovalOverride");

      final response = await handler.routeForTest(
        makeRequest("PATCH", "/session/approval-override", body: body(approvalOverride: SessionApprovalMode.ask)),
      );

      expect(response.status, 404);
      expect(
        SessionApprovalOverrideErrorResponse.fromJson(jsonDecodeMap(response.body ?? "")).code,
        SessionApprovalOverrideErrorCode.sessionNotFound,
      );
    });
  });
}

class _FakeYoloSettingsService() implements YoloSettingsService {
  final List<({String sessionId, SessionApprovalMode? approvalOverride})> calls = [];
  Object? error;

  @override
  Future<Session> setSessionOverride({
    required String sessionId,
    required SessionApprovalMode? approvalOverride,
  }) async {
    calls.add((sessionId: sessionId, approvalOverride: approvalOverride));
    if (error case final error?) throw error;
    return Session(
      id: sessionId,
      projectID: "project-1",
      directory: "/repo",
      parentID: null,
      title: null,
      time: null,
      pullRequest: null,
      promptDefaults: null,
      branchName: null,
      lastUserActivityAt: null,
      autoContinuation: null,
      approvalOverride: approvalOverride,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSessionViewService() implements SessionViewService {
  @override
  Future<Session> enrich({required Session session}) async => session.copyWith(title: "enriched");

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
