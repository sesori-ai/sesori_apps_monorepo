import "dart:async";

import "package:sesori_bridge/src/bridge/repositories/models/session_operation.dart";
import "package:sesori_bridge/src/bridge/repositories/permission_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/question_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/services/pending_interaction_service.dart";
import "package:sesori_bridge/src/bridge/services/permission_auto_approval_service.dart";
import "package:sesori_bridge/src/bridge/services/session_operation_dispatcher.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("PendingInteractionService", () {
    late _FamilyRepository sessionRepository;
    late _PermissionRepository permissionRepository;
    late _QuestionRepository questionRepository;
    late SessionOperationDispatcher dispatcher;
    late PendingInteractionService service;
    late PermissionAutoApprovalService autoApproval;

    setUp(() {
      sessionRepository = _FamilyRepository({
        "session-one": (rootSessionId: "root-one", pluginId: "legacy"),
        "session-two": (rootSessionId: "root-two", pluginId: "legacy"),
      });
      permissionRepository = _PermissionRepository();
      questionRepository = _QuestionRepository();
      dispatcher = SessionOperationDispatcher(sessionRepository: sessionRepository);
      service = PendingInteractionService(
        permissionRepository: permissionRepository,
        questionRepository: questionRepository,
        dispatcher: dispatcher,
        legacyMissingPluginId: "legacy",
      );
      autoApproval = PermissionAutoApprovalService(
        sessionRepository: sessionRepository,
        permissionRepository: permissionRepository,
        pendingInteractionService: service,
      );
    });

    tearDown(() async {
      autoApproval.dispose();
      await dispatcher.dispose();
      service.dispose();
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
  });
}

class _FamilyRepository implements SessionRepository {
  final Map<String, SessionFamilyScope> scopes;

  _FamilyRepository(this.scopes);

  @override
  Future<SessionFamilyScope> resolveSessionFamily({
    required String sessionId,
    required SessionOperation operation,
  }) async => scopes[sessionId]!;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PermissionRepository implements PermissionRepository {
  final List<PermissionReply> calls = [];
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _QuestionRepository implements QuestionRepository {
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
