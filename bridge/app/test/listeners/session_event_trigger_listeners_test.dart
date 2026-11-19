import "dart:async";

import "package:sesori_bridge/src/listeners/session_binding_commit_listener.dart";
import "package:sesori_bridge/src/listeners/session_mutation_listener.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/services/session_event_dispatcher.dart";
import "package:sesori_bridge/src/services/session_mutation_dispatcher.dart";
import "package:sesori_bridge/src/services/session_view_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
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

  group("mutation listener", () {
    late StreamController<LocalSessionMutation> source;
    late _RecordingDispatcher dispatcher;
    late SessionMutationListener listener;

    setUp(() {
      source = StreamController<LocalSessionMutation>.broadcast();
      dispatcher = _RecordingDispatcher();
      listener = SessionMutationListener(
        source: source.stream,
        views: const _PinningSessionViews(),
        dispatcher: dispatcher,
      );
      listener.start();
    });

    tearDown(() async {
      await listener.dispose();
      await source.close();
    });

    test("forwards a rename as an updated session", () async {
      source.add(SessionTitleUpdated(session: _session(archived: null)));
      await Future<void>.delayed(Duration.zero);

      expect(dispatcher.localEvents, [
        _localEvent(events: [_updated(session: _session(archived: null), titleChanged: true)]),
      ]);
    });

    test("tells every client an archived session was updated, then rebuilds the summary", () async {
      source.add(SessionArchived(session: _session(archived: 300)));
      await Future<void>.delayed(Duration.zero);

      expect(dispatcher.localEvents, [
        _localEvent(
          events: [
            _updated(session: _session(archived: 300), titleChanged: false),
            isA<BridgeSseProjectUpdated>(),
          ],
        ),
      ]);
    });
  });
}

Matcher _localEvent({required List<Matcher> events}) => isA<LocalSessionEvent>()
    .having((event) => event.pluginId, "pluginId", "plugin")
    .having((event) => event.events, "events", events);

/// The enriched [session], as the listener sends it.
Matcher _updated({required Session session, required bool titleChanged}) => isA<BridgeSseSessionUpdated>()
    .having((event) => event.info, "info", equals(session.copyWith(pinOrder: 1).toJson()))
    .having((event) => event.titleChanged, "titleChanged", titleChanged);

Session _session({required int? archived}) => Session(
  approvalOverride: null,
  autoContinuation: null,
  branchName: null,
  id: "s1",
  pluginId: "plugin",
  projectID: "/repo",
  directory: "/repo",
  parentID: null,
  forkedFrom: null,
  title: null,
  time: SessionTime(created: 100, updated: 200, archived: archived),
  promptDefaults: null,
  lastUserActivityAt: null,
  pinOrder: null,
  scheduledTask: null,
  interruption: null,
);

/// Marks each session so a test can tell it was enriched.
final class const _PinningSessionViews() implements SessionViewService {
  @override
  Future<Session> enrich({required Session session}) async => session.copyWith(pinOrder: 1);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
