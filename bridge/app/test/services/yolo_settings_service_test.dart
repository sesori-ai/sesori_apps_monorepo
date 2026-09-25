import "dart:async";

import "package:sesori_bridge/src/repositories/bridge_settings_repository.dart";
import "package:sesori_bridge/src/services/permission_auto_approval_service.dart";
import "package:sesori_bridge/src/services/session_mutation_dispatcher.dart";
import "package:sesori_bridge/src/services/yolo_settings_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/in_memory_bridge_settings_api.dart";

void main() {
  group("YoloSettingsService", () {
    late InMemoryBridgeSettingsApi api;
    late _FakePermissionAutoApprovalService permissionAutoApprovalService;
    late _FakeSessionMutationDispatcher sessionMutationDispatcher;
    late BridgeSettingsRepository repository;
    late YoloSettingsService service;

    setUp(() async {
      api = InMemoryBridgeSettingsApi(
        config: '{"yolo":false,"pullRequestRefreshIntervalSeconds":30,"warmUpPluginsOnSessionOpen":true}',
      );
      repository = BridgeSettingsRepository(defaultEditorApi: null, api: api);
      await repository.loadSettings();
      permissionAutoApprovalService = _FakePermissionAutoApprovalService();
      sessionMutationDispatcher = _FakeSessionMutationDispatcher();
      service = YoloSettingsService(
        bridgeSettingsRepository: repository,
        permissionAutoApprovalService: permissionAutoApprovalService,
        sessionMutationDispatcher: sessionMutationDispatcher,
      );
    });

    tearDown(() => repository.dispose());

    test("enabling persists and approves pending permissions", () async {
      expect(
        await service.update(enabled: true),
        const YoloSettingsResponse(enabled: true, supportsSessionOverride: true),
      );

      expect(repository.currentSettings.yolo, isTrue);
      expect(jsonDecodeMap(api.config!)["yolo"], isTrue);
      expect(permissionAutoApprovalService.approvePendingCalls, 1);
    });

    test("disabling persists without approving pending permissions", () async {
      await service.update(enabled: true);
      permissionAutoApprovalService.approvePendingCalls = 0;

      expect(
        await service.update(enabled: false),
        const YoloSettingsResponse(enabled: false, supportsSessionOverride: true),
      );

      expect(jsonDecodeMap(api.config!)["yolo"], isFalse);
      expect(permissionAutoApprovalService.approvePendingCalls, 0);
    });

    test("an unchanged value does not rewrite or approve pending permissions", () async {
      await service.update(enabled: true);
      permissionAutoApprovalService.approvePendingCalls = 0;

      await service.update(enabled: true);

      expect(api.writeCount, 1);
      expect(permissionAutoApprovalService.approvePendingCalls, 0);
    });

    test("a session override that puts the session in YOLO approves pending permissions", () async {
      permissionAutoApprovalService.yoloSessions.add("session-1");

      final session = await service.setSessionOverride(
        sessionId: "session-1",
        approvalOverride: SessionApprovalMode.yolo,
      );

      expect(session.approvalOverride, SessionApprovalMode.yolo);
      expect(sessionMutationDispatcher.calls, [(sessionId: "session-1", approvalOverride: SessionApprovalMode.yolo)]);
      expect(permissionAutoApprovalService.approvePendingCalls, 1);
    });

    test("a session override that leaves the session asking approves nothing", () async {
      await service.setSessionOverride(sessionId: "session-1", approvalOverride: SessionApprovalMode.ask);

      expect(sessionMutationDispatcher.calls.single.approvalOverride, SessionApprovalMode.ask);
      expect(permissionAutoApprovalService.approvePendingCalls, 0);
    });
  });
}

class _FakePermissionAutoApprovalService() implements PermissionAutoApprovalService {
  int approvePendingCalls = 0;
  final Set<String> yoloSessions = {};

  @override
  Future<void> approvePending() async => approvePendingCalls++;

  @override
  Future<bool> isYolo({required String sessionId}) async => yoloSessions.contains(sessionId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSessionMutationDispatcher() implements SessionMutationDispatcher {
  final List<({String sessionId, SessionApprovalMode? approvalOverride})> calls = [];

  @override
  Future<Session> setApprovalOverride({
    required String sessionId,
    required SessionApprovalMode? approvalOverride,
  }) async {
    calls.add((sessionId: sessionId, approvalOverride: approvalOverride));
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
