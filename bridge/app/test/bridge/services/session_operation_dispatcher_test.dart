import "dart:async";

import "package:sesori_bridge/src/bridge/repositories/models/session_operation.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/services/session_operation_dispatcher.dart";
import "package:test/test.dart";

void main() {
  group("SessionOperationDispatcher", () {
    test("orders one family while unrelated families and plugins run", () async {
      final repository = _FamilyRepository({
        "root": (rootSessionId: "root", pluginId: "one"),
        "child": (rootSessionId: "root", pluginId: "one"),
        "other": (rootSessionId: "other", pluginId: "one"),
        "plugin-two": (rootSessionId: "plugin-two", pluginId: "two"),
      });
      final dispatcher = SessionOperationDispatcher(sessionRepository: repository);
      addTearDown(dispatcher.dispose);
      final rootGate = Completer<void>();
      final rootStarted = Completer<void>();
      final childStarted = Completer<void>();
      final otherStarted = Completer<void>();
      final pluginTwoStarted = Completer<void>();

      final root = dispatcher.dispatch<void>(
        sessionId: "root",
        operation: SessionOperation.sendPrompt,
        interaction: null,
        body: () async {
          rootStarted.complete();
          await rootGate.future;
        },
      );
      final child = dispatcher.dispatch<void>(
        sessionId: "child",
        operation: SessionOperation.abortSession,
        interaction: null,
        body: () async => childStarted.complete(),
      );
      final other = dispatcher.dispatch<void>(
        sessionId: "other",
        operation: SessionOperation.sendPrompt,
        interaction: null,
        body: () async => otherStarted.complete(),
      );
      final pluginTwo = dispatcher.dispatch<void>(
        sessionId: "plugin-two",
        operation: SessionOperation.sendPrompt,
        interaction: null,
        body: () async => pluginTwoStarted.complete(),
      );

      await Future.wait([rootStarted.future, otherStarted.future, pluginTwoStarted.future]);
      expect(childStarted.isCompleted, isFalse);
      rootGate.complete();
      await Future.wait([root, child, other, pluginTwo]);
      expect(childStarted.isCompleted, isTrue);
      expect(dispatcher.activeLaneCount, isZero);
    });

    test("isolates reused interaction IDs and releases a failed lane", () async {
      final repository = _FamilyRepository({
        "a": (rootSessionId: "a", pluginId: "one"),
        "b": (rootSessionId: "b", pluginId: "one"),
        "c": (rootSessionId: "c", pluginId: "two"),
      });
      final dispatcher = SessionOperationDispatcher(sessionRepository: repository);
      addTearDown(dispatcher.dispose);
      final gate = Completer<void>();
      final firstStarted = Completer<void>();
      final sameStarted = Completer<void>();
      final otherFamilyStarted = Completer<void>();
      final otherPluginStarted = Completer<void>();

      final first = dispatcher.dispatch<void>(
        sessionId: "a",
        operation: SessionOperation.replyToQuestion,
        interaction: const PendingQuestionInteraction(requestId: "reused"),
        body: () async {
          firstStarted.complete();
          await gate.future;
          throw StateError("first response failed");
        },
      );
      final same = dispatcher.dispatch<void>(
        sessionId: "a",
        operation: SessionOperation.rejectQuestion,
        interaction: const PendingQuestionInteraction(requestId: "reused"),
        body: () async => sameStarted.complete(),
      );
      final otherFamily = dispatcher.dispatch<void>(
        sessionId: "b",
        operation: SessionOperation.rejectQuestion,
        interaction: const PendingQuestionInteraction(requestId: "reused"),
        body: () async => otherFamilyStarted.complete(),
      );
      final otherPlugin = dispatcher.dispatch<void>(
        sessionId: "c",
        operation: SessionOperation.rejectQuestion,
        interaction: const PendingQuestionInteraction(requestId: "reused"),
        body: () async => otherPluginStarted.complete(),
      );

      await Future.wait([firstStarted.future, otherFamilyStarted.future, otherPluginStarted.future]);
      expect(sameStarted.isCompleted, isFalse);
      gate.complete();
      await expectLater(first, throwsStateError);
      await Future.wait([same, otherFamily, otherPlugin]);
      expect(sameStarted.isCompleted, isTrue);
      expect(dispatcher.activeLaneCount, isZero);
    });

    test("legacy owner resolution blocks only later admissions for its plugin", () async {
      final repository = _FamilyRepository({
        "legacy-owner": (rootSessionId: "legacy-owner", pluginId: "legacy"),
        "other-plugin": (rootSessionId: "other-plugin", pluginId: "other"),
      });
      final dispatcher = SessionOperationDispatcher(sessionRepository: repository);
      addTearDown(dispatcher.dispose);
      final ownerLookupStarted = Completer<void>();
      final ownerGate = Completer<void>();
      final legacyBodyStarted = Completer<void>();
      final legacyBodyGate = Completer<void>();
      final laterStarted = Completer<void>();
      final otherPluginStarted = Completer<void>();

      final legacy = dispatcher.dispatchLegacyQuestion<void>(
        pluginId: "legacy",
        questionId: "question",
        operation: SessionOperation.rejectQuestion,
        resolveOwnerSessionId: () async {
          ownerLookupStarted.complete();
          await ownerGate.future;
          return "legacy-owner";
        },
        body: (_) async {
          legacyBodyStarted.complete();
          await legacyBodyGate.future;
        },
      );
      final later = dispatcher.dispatch<void>(
        sessionId: "legacy-owner",
        operation: SessionOperation.abortSession,
        interaction: null,
        body: () async => laterStarted.complete(),
      );
      final otherPlugin = dispatcher.dispatch<void>(
        sessionId: "other-plugin",
        operation: SessionOperation.abortSession,
        interaction: null,
        body: () async => otherPluginStarted.complete(),
      );

      await Future.wait([ownerLookupStarted.future, otherPluginStarted.future]);
      expect(laterStarted.isCompleted, isFalse);
      ownerGate.complete();
      await legacyBodyStarted.future;
      expect(laterStarted.isCompleted, isFalse);
      legacyBodyGate.complete();
      await Future.wait([legacy, later, otherPlugin]);
      expect(laterStarted.isCompleted, isTrue);
      expect(dispatcher.activeLaneCount, isZero);
    });

    test("resolves tickets in order and closes acceptance on repeated drain", () async {
      final firstResolutionGate = Completer<void>();
      final firstResolutionStarted = Completer<void>();
      final repository =
          _FamilyRepository({
              "first": (rootSessionId: "first", pluginId: "one"),
              "second": (rootSessionId: "second", pluginId: "one"),
            })
            ..beforeResolve = (sessionId) async {
              if (sessionId == "first") {
                firstResolutionStarted.complete();
                await firstResolutionGate.future;
              }
            };
      final dispatcher = SessionOperationDispatcher(sessionRepository: repository);
      final first = dispatcher.dispatch<void>(
        sessionId: "first",
        operation: SessionOperation.sendPrompt,
        interaction: null,
        body: () async {},
      );
      final second = dispatcher.dispatch<void>(
        sessionId: "second",
        operation: SessionOperation.sendPrompt,
        interaction: null,
        body: () async {},
      );
      await firstResolutionStarted.future;
      expect(repository.resolutionOrder, ["first"]);

      final drain = dispatcher.drain();
      expect(identical(drain, dispatcher.drain()), isTrue);
      expect(identical(drain, dispatcher.dispose()), isTrue);
      await expectLater(
        dispatcher.dispatch<void>(
          sessionId: "second",
          operation: SessionOperation.abortSession,
          interaction: null,
          body: () async {},
        ),
        throwsStateError,
      );
      firstResolutionGate.complete();
      await Future.wait([first, second, drain]);
      expect(repository.resolutionOrder, ["first", "second"]);
      expect(dispatcher.activeLaneCount, isZero);
    });
  });
}

class _FamilyRepository implements SessionRepository {
  final Map<String, SessionFamilyScope> scopes;
  final List<String> resolutionOrder = [];
  Future<void> Function(String sessionId)? beforeResolve;

  _FamilyRepository(this.scopes);

  @override
  Future<SessionFamilyScope> resolveSessionFamily({
    required String sessionId,
    required SessionOperation operation,
  }) async {
    resolutionOrder.add(sessionId);
    await beforeResolve?.call(sessionId);
    return scopes[sessionId]!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
