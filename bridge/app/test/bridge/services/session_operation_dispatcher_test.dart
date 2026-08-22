import "dart:async";

import "package:sesori_bridge/src/repositories/models/session_operation.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/services/session_operation_dispatcher.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginOperationException;
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
        body: () async {
          rootStarted.complete();
          await rootGate.future;
        },
      );
      final child = dispatcher.dispatch<void>(
        sessionId: "child",
        operation: SessionOperation.abortSession,
        body: () async => childStarted.complete(),
      );
      final other = dispatcher.dispatch<void>(
        sessionId: "other",
        operation: SessionOperation.sendPrompt,
        body: () async => otherStarted.complete(),
      );
      final pluginTwo = dispatcher.dispatch<void>(
        sessionId: "plugin-two",
        operation: SessionOperation.sendPrompt,
        body: () async => pluginTwoStarted.complete(),
      );

      await Future.wait([rootStarted.future, otherStarted.future, pluginTwoStarted.future]);
      expect(childStarted.isCompleted, isFalse);
      rootGate.complete();
      await Future.wait([root, child, other, pluginTwo]);
      expect(childStarted.isCompleted, isTrue);
      expect(dispatcher.activeLaneCount, isZero);
    });

    test("releases a failed family lane while unrelated families run", () async {
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
        body: () async {
          firstStarted.complete();
          await gate.future;
          throw StateError("first response failed");
        },
      );
      final same = dispatcher.dispatch<void>(
        sessionId: "a",
        operation: SessionOperation.rejectQuestion,
        body: () async => sameStarted.complete(),
      );
      final otherFamily = dispatcher.dispatch<void>(
        sessionId: "b",
        operation: SessionOperation.rejectQuestion,
        body: () async => otherFamilyStarted.complete(),
      );
      final otherPlugin = dispatcher.dispatch<void>(
        sessionId: "c",
        operation: SessionOperation.rejectQuestion,
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
        "earlier": (rootSessionId: "earlier", pluginId: "legacy"),
        "legacy-owner": (rootSessionId: "legacy-owner", pluginId: "legacy"),
        "other-plugin": (rootSessionId: "other-plugin", pluginId: "other"),
      });
      final dispatcher = SessionOperationDispatcher(sessionRepository: repository);
      addTearDown(dispatcher.dispose);
      final earlierGate = Completer<void>();
      final earlierStarted = Completer<void>();
      final ownerLookupStarted = Completer<void>();
      final ownerGate = Completer<void>();
      final legacyBodyStarted = Completer<void>();
      final legacyBodyGate = Completer<void>();
      final laterStarted = Completer<void>();
      final otherPluginStarted = Completer<void>();

      final earlier = dispatcher.dispatch<void>(
        sessionId: "earlier",
        operation: SessionOperation.replyToQuestion,
        body: () async {
          earlierStarted.complete();
          await earlierGate.future;
        },
      );
      await earlierStarted.future;
      final legacy = dispatcher.dispatchLegacyQuestion<void>(
        pluginId: "legacy",
        questionId: "question",
        operation: SessionOperation.rejectQuestion,
        resolveOwnerSessionId: () async {
          ownerLookupStarted.complete();
          await ownerGate.future;
          return "legacy-owner";
        },
        body: ({required String ownerSessionId}) async {
          legacyBodyStarted.complete();
          await legacyBodyGate.future;
        },
      );
      final later = dispatcher.dispatch<void>(
        sessionId: "legacy-owner",
        operation: SessionOperation.abortSession,
        body: () async => laterStarted.complete(),
      );
      final otherPlugin = dispatcher.dispatch<void>(
        sessionId: "other-plugin",
        operation: SessionOperation.abortSession,
        body: () async => otherPluginStarted.complete(),
      );

      await otherPluginStarted.future;
      expect(ownerLookupStarted.isCompleted, isFalse);
      expect(laterStarted.isCompleted, isFalse);
      earlierGate.complete();
      await ownerLookupStarted.future;
      ownerGate.complete();
      await legacyBodyStarted.future;
      expect(laterStarted.isCompleted, isFalse);
      legacyBodyGate.complete();
      await Future.wait([earlier, legacy, later, otherPlugin]);
      expect(laterStarted.isCompleted, isTrue);
      expect(dispatcher.activeLaneCount, isZero);
    });

    test("legacy owner plugin mismatch releases later plugin admission", () async {
      final repository = _FamilyRepository({
        "wrong-owner": (rootSessionId: "wrong-owner", pluginId: "other"),
        "later": (rootSessionId: "later", pluginId: "legacy"),
      });
      final dispatcher = SessionOperationDispatcher(sessionRepository: repository);
      addTearDown(dispatcher.dispose);
      var legacyBodyCalled = false;

      final legacy = dispatcher.dispatchLegacyQuestion<void>(
        pluginId: "legacy",
        questionId: "question",
        operation: SessionOperation.rejectQuestion,
        resolveOwnerSessionId: () async => "wrong-owner",
        body: ({required String ownerSessionId}) async {
          legacyBodyCalled = true;
        },
      );
      final later = dispatcher.dispatch<void>(
        sessionId: "later",
        operation: SessionOperation.abortSession,
        body: () async {},
      );

      await expectLater(
        legacy,
        throwsA(
          isA<PluginOperationException>().having((error) => error.statusCode, "statusCode", 409),
        ),
      );
      await later;
      expect(legacyBodyCalled, isFalse);
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
        body: () async {},
      );
      final second = dispatcher.dispatch<void>(
        sessionId: "second",
        operation: SessionOperation.sendPrompt,
        body: () async {},
      );
      await firstResolutionStarted.future;
      expect(repository.resolutionOrder, ["first"]);

      final drain = dispatcher.drain();
      expect(identical(drain, dispatcher.drain()), isTrue);
      expect(identical(drain, dispatcher.dispose()), isTrue);
      expect(
        () => dispatcher.dispatch<void>(
          sessionId: "second",
          operation: SessionOperation.abortSession,
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

class _FamilyRepository(final Map<String, SessionFamilyScope> scopes) implements SessionRepository {
  final List<String> resolutionOrder = [];
  Future<void> Function(String sessionId)? beforeResolve;

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
