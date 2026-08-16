import "dart:async";

import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/services/session_event_dispatcher.dart";
import "package:sesori_bridge/src/listeners/session_binding_commit_listener.dart";
import "package:sesori_bridge/src/listeners/session_mutation_listener.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
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

    source.add((
      pluginId: "other",
      projectId: "other-project",
      generation: 1,
      kind: SessionBindingCommitKind.catalogSync,
      backendSessionIds: const ["ignored"],
    ));
    source.add((
      pluginId: "selected",
      projectId: "selected-project",
      generation: 2,
      kind: SessionBindingCommitKind.sessionCreation,
      backendSessionIds: const ["root"],
    ));
    await Future<void>.delayed(Duration.zero);

    expect(dispatcher.commits, [
      (
        pluginId: "other",
        projectId: "other-project",
        generation: 1,
        kind: SessionBindingCommitKind.catalogSync,
        backendSessionIds: const ["ignored"],
      ),
      (
        pluginId: "selected",
        projectId: "selected-project",
        generation: 2,
        kind: SessionBindingCommitKind.sessionCreation,
        backendSessionIds: const ["root"],
      ),
    ]);
    await listener.dispose();
    await source.close();
  });

  test("mutation listener forwards mapped local events", () async {
    final source = StreamController<LocalSessionEvent>.broadcast();
    final dispatcher = _RecordingDispatcher();
    final listener = SessionMutationListener(source: source.stream, dispatcher: dispatcher);
    listener.start();
    const updated = (
      pluginId: "plugin",
      event: BridgeSseSessionUpdated(info: <String, dynamic>{}, titleChanged: true),
    );
    const deleted = (pluginId: "plugin", event: BridgeSseSessionDeleted(info: <String, dynamic>{}));

    source
      ..add(updated)
      ..add(deleted);
    await Future<void>.delayed(Duration.zero);

    expect(dispatcher.localEvents, [updated, deleted]);
    await listener.dispose();
    await source.close();
  });
}

class _RecordingDispatcher() implements SessionEventDispatcher {
  final List<SessionBindingsCommitted> commits = [];
  final List<LocalSessionEvent> localEvents = [];

  @override
  Future<void> dispatchBindingsCommitted({required SessionBindingsCommitted commit}) async {
    commits.add(commit);
  }

  @override
  Future<void> dispatchLocalEvent({required LocalSessionEvent source}) async {
    localEvents.add(source);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
