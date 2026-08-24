import "dart:async";

import "package:sesori_bridge/src/repositories/bridge_settings_repository.dart";
import "package:sesori_bridge/src/repositories/models/session_operation.dart";
import "package:sesori_bridge/src/repositories/models/stored_session.dart";
import "package:sesori_bridge/src/repositories/permission_repository.dart";
import "package:sesori_bridge/src/repositories/question_repository.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/services/archived_session_validator.dart";
import "package:sesori_bridge/src/services/pending_interaction_service.dart";
import "package:sesori_bridge/src/services/permission_auto_approval_service.dart";
import "package:sesori_bridge/src/services/session_operation_dispatcher.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/in_memory_bridge_settings_api.dart";

void main() {
  group("PendingInteractionService", () {
    late _FamilyRepository sessionRepository;
    late _PermissionRepository permissionRepository;
    late _QuestionRepository questionRepository;
    late SessionOperationDispatcher dispatcher;
    late PendingInteractionService service;
    late PermissionAutoApprovalService autoApproval;
    late BridgeSettingsRepository settingsRepository;

    setUp(() async {
      sessionRepository = _FamilyRepository({
        "session-one": (rootSessionId: "root-one", pluginId: "legacy"),
        "session-two": (rootSessionId: "root-two", pluginId: "legacy"),
      });
      permissionRepository = _PermissionRepository();
      questionRepository = _QuestionRepository();
      settingsRepository = BridgeSettingsRepository(
        api: InMemoryBridgeSettingsApi(config: '{"yolo":true,"pullRequestRefreshIntervalSeconds":30}'),
      );
      await settingsRepository.loadSettings();
      dispatcher = SessionOperationDispatcher(sessionRepository: sessionRepository);
      service = PendingInteractionService(
        permissionRepository: permissionRepository,
        questionRepository: questionRepository,
        dispatcher: dispatcher,
        archivedSessionValidator: ArchivedSessionValidator(sessionRepository: sessionRepository),
      );
      autoApproval = PermissionAutoApprovalService(
        sessionRepository: sessionRepository,
        permissionRepository: permissionRepository,
        pendingInteractionService: service,
        bridgeSettingsRepository: settingsRepository,
      );
    });

    tearDown(() async {
      autoApproval.dispose();
      await dispatcher.dispose();
      service.dispose();
      await settingsRepository.dispose();
    });

    test("keeps first permission and question responses authoritative", () async {
      final permissionGate = Completer<void>();
      final permissionStarted = Completer<void>();
      permissionRepository.onReply = ({required requestId, required sessionId, required reply}) async {
        if (permissionRepository.calls.isEmpty) {
          permissionStarted.complete();
          await permissionGate.future;
        }
        permissionRepository.calls.add(reply);
      };

      final automatic = autoApproval.approve(requestId: "permission", sessionId: "session-one");
      await permissionStarted.future;
      final rejection = service.replyToPermission(
        requestId: "permission",
        sessionId: "session-one",
        reply: PermissionReply.reject,
      );
      await Future<void>.delayed(Duration.zero);
      expect(permissionRepository.calls, isEmpty);
      permissionGate.complete();
      await Future.wait([automatic, rejection]);
      expect(permissionRepository.calls, [PermissionReply.once, PermissionReply.reject]);

      final questionGate = Completer<void>();
      final questionStarted = Completer<void>();
      questionRepository.onReply = ({required questionId, required sessionId, required answers}) async {
        questionRepository.calls.add("answer");
        questionStarted.complete();
        await questionGate.future;
      };
      final answer = service.replyToQuestion(
        questionId: "question",
        sessionId: "session-one",
        answers: const [
          ReplyAnswer(values: ["yes"]),
        ],
      );
      await questionStarted.future;
      final reject = service.rejectQuestion(questionId: "question", sessionId: "session-one");
      await Future<void>.delayed(Duration.zero);
      expect(questionRepository.calls, ["answer"]);
      questionGate.complete();
      await Future.wait([answer, reject]);
      expect(questionRepository.calls, ["answer", "reject:session-one"]);

      dispatcher.beginShutdown();
      await expectLater(
        autoApproval.approve(requestId: "closed", sessionId: "session-one"),
        throwsStateError,
      );
      expect(permissionRepository.calls, hasLength(2));
    });

    test("stops an in-progress pending scan after yolo is disabled", () async {
      sessionRepository.activitySummaries = const [
        ProjectActivitySummary(
          id: "project",
          activeSessions: [
            ActiveSession(id: "session-one", awaitingInput: true, lastUserActivityAt: null, updatedAt: null),
          ],
        ),
      ];
      permissionRepository.pendingPermissions = const [
        PendingPermission(
          id: "first",
          sessionID: "session-one",
          displaySessionId: null,
          tool: "tool",
          description: "first",
        ),
        PendingPermission(
          id: "second",
          sessionID: "session-one",
          displaySessionId: null,
          tool: "tool",
          description: "second",
        ),
      ];
      final firstStarted = Completer<void>();
      final firstGate = Completer<void>();
      permissionRepository.onReply = ({required requestId, required sessionId, required reply}) async {
        permissionRepository.requestIds.add(requestId);
        if (requestId == "first") {
          firstStarted.complete();
          await firstGate.future;
        }
      };

      final scan = autoApproval.approvePending();
      await firstStarted.future;
      await settingsRepository.updateYolo(enabled: false);
      firstGate.complete();
      await scan;

      expect(permissionRepository.requestIds, ["first"]);
    });

    test("a resolved snapshot approves each permission and hides the approved ones", () async {
      const permission = PendingPermission(
        id: "first",
        sessionID: "session-one",
        displaySessionId: null,
        tool: "tool",
        description: "first",
      );
      permissionRepository.onReply = ({required requestId, required sessionId, required reply}) async {
        permissionRepository.requestIds.add(requestId);
      };

      final unresolved = await autoApproval.resolveSnapshot(permissions: const [permission]);

      expect(unresolved, isEmpty);
      expect(permissionRepository.requestIds, ["first"]);
    });

    test("a snapshot permission whose approval fails stays visible", () async {
      const failing = PendingPermission(
        id: "failing",
        sessionID: "session-one",
        displaySessionId: null,
        tool: "tool",
        description: "failing",
      );
      const working = PendingPermission(
        id: "working",
        sessionID: "session-one",
        displaySessionId: null,
        tool: "tool",
        description: "working",
      );
      permissionRepository.onReply = ({required requestId, required sessionId, required reply}) async {
        if (requestId == "failing") throw StateError("backend rejected the reply");
        permissionRepository.requestIds.add(requestId);
      };

      final unresolved = await autoApproval.resolveSnapshot(permissions: const [failing, working]);

      expect(unresolved.map((permission) => permission.id), ["failing"]);
      expect(permissionRepository.requestIds, ["working"]);
    });

    test("disabling yolo mid-snapshot keeps the remaining permissions visible", () async {
      const first = PendingPermission(
        id: "first",
        sessionID: "session-one",
        displaySessionId: null,
        tool: "tool",
        description: "first",
      );
      const second = PendingPermission(
        id: "second",
        sessionID: "session-one",
        displaySessionId: null,
        tool: "tool",
        description: "second",
      );
      permissionRepository.onReply = ({required requestId, required sessionId, required reply}) async {
        permissionRepository.requestIds.add(requestId);
        await settingsRepository.updateYolo(enabled: false);
      };

      final unresolved = await autoApproval.resolveSnapshot(permissions: const [first, second]);

      expect(permissionRepository.requestIds, ["first"]);
      expect(unresolved.map((permission) => permission.id), ["second"]);
    });

    test("the snapshot passes through untouched when yolo is off", () async {
      await settingsRepository.updateYolo(enabled: false);
      const permission = PendingPermission(
        id: "first",
        sessionID: "session-one",
        displaySessionId: null,
        tool: "tool",
        description: "first",
      );

      final unresolved = await autoApproval.resolveSnapshot(permissions: const [permission]);

      expect(unresolved, [permission]);
      expect(permissionRepository.requestIds, isEmpty);
    });
  });
}

class _FamilyRepository(final Map<String, SessionFamilyScope> scopes) implements SessionRepository {
  List<ProjectActivitySummary> activitySummaries = const [];

  @override
  Future<SessionFamilyScope> resolveSessionFamily({
    required String sessionId,
    required SessionOperation operation,
  }) async => scopes[sessionId]!;

  @override
  Future<StoredSession?> getStoredSession({required String sessionId}) async => null;

  @override
  Future<List<ProjectActivitySummary>> getProjectActivitySummaries() async => activitySummaries;

  @override
  Future<List<Session>> getChildSessions({required String sessionId}) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PermissionRepository() implements PermissionRepository {
  final List<PermissionReply> calls = [];
  final List<String> requestIds = [];
  List<PendingPermission> pendingPermissions = const [];
  Future<void> Function({required String requestId, required String sessionId, required PermissionReply reply})?
  onReply;

  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PermissionReply reply,
  }) async {
    await onReply?.call(requestId: requestId, sessionId: sessionId, reply: reply);
  }

  @override
  Future<List<PendingPermission>> getPendingPermissions({required String sessionId}) async => pendingPermissions;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QuestionRepository() implements QuestionRepository {
  final List<String> calls = [];
  Future<void> Function({required String questionId, required String sessionId, required List<ReplyAnswer> answers})?
  onReply;

  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<ReplyAnswer> answers,
  }) async {
    await onReply?.call(questionId: questionId, sessionId: sessionId, answers: answers);
  }

  @override
  Future<void> rejectQuestion({required String questionId, required String sessionId}) async {
    calls.add("reject:$sessionId");
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
