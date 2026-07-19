import "dart:async";

import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/services/session_event_dispatcher.dart";
import "package:sesori_bridge/src/listeners/session_binding_commit_listener.dart";
import "package:sesori_bridge/src/listeners/session_deletion_listener.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("binding listener forwards commits from every plugin", () async {
    final source = StreamController<SessionBindingsCommitted>.broadcast();
    final dispatcher = _RecordingDispatcher();
    final listener = SessionBindingCommitListener(
      source: source.stream,
      dispatcher: dispatcher,
    );
    listener.start();

    source.add((pluginId: "other", backendSessionIds: const ["ignored"]));
    source.add((pluginId: "selected", backendSessionIds: const ["root"]));
    await Future<void>.delayed(Duration.zero);

    expect(dispatcher.commits, [
      (pluginId: "other", backendSessionIds: const ["ignored"]),
      (pluginId: "selected", backendSessionIds: const ["root"]),
    ]);
    await listener.dispose();
    await source.close();
  });

  test("deletion listener forwards committed stable sessions", () async {
    final source = StreamController<Session>.broadcast();
    final dispatcher = _RecordingDispatcher();
    final listener = SessionDeletionListener(source: source.stream, dispatcher: dispatcher);
    listener.start();
    const deleted = Session(
      id: "stable-root",
      pluginId: "plugin",
      projectID: "project",
      directory: "/repo",
      parentID: null,
      title: null,
      time: null,
      pullRequest: null,
      promptDefaults: null,
      branchName: null,
    );

    source.add(deleted);
    await Future<void>.delayed(Duration.zero);

    expect(dispatcher.deletedSessions, [deleted]);
    await listener.dispose();
    await source.close();
  });
}

class _RecordingDispatcher implements SessionEventDispatcher {
  final List<SessionBindingsCommitted> commits = [];
  final List<Session> deletedSessions = [];

  @override
  Future<void> dispatchBindingsCommitted({required SessionBindingsCommitted commit}) async {
    commits.add(commit);
  }

  @override
  Future<void> dispatchDeletedSession({required Session session}) async {
    deletedSessions.add(session);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
