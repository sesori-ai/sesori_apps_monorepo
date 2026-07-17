import "dart:async";

import "package:sesori_bridge/src/bridge/repositories/models/command_timeline.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/bridge/services/command_timeline_mutation.dart";
import "package:sesori_bridge/src/bridge/services/command_timeline_service.dart";
import "package:sesori_bridge/src/bridge/services/session_event_enrichment_service.dart";
import "package:sesori_bridge/src/bridge/services/session_mutation_dispatcher.dart";
import "package:sesori_bridge/src/listeners/plugin_command_timeline_listener.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_database.dart";
import "../helpers/test_helpers.dart";

void main() {
  test("relay and debug subscribers share one plugin-event canonicalization", () async {
    final db = createTestDatabase();
    final plugin = _EventPlugin();
    final repository = SessionRepository(
      plugin: plugin,
      sessionDao: db.sessionDao,
      projectsDao: db.projectsDao,
      pullRequestDao: db.pullRequestDao,
      unseenCalculator: const SessionUnseenCalculator(),
    );
    final mutationDispatcher = SessionMutationDispatcher(sessionRepository: repository);
    final timeline = _CountingTimelineService();
    final listener = PluginCommandTimelineListener(
      sessionRepository: repository,
      enrichmentService: SessionEventEnrichmentService(
        sessionRepository: repository,
        sessionMutationDispatcher: mutationDispatcher,
        failureReporter: FakeFailureReporter(),
      ),
      timelineService: timeline,
    );
    addTearDown(() async {
      await listener.dispose();
      await mutationDispatcher.dispose();
      await plugin.close();
      await db.close();
    });
    await listener.start();
    await listener.start();
    final relayOutput = listener.outputs.first;
    final debugOutput = listener.outputs.first;

    plugin.add(
      const BridgeSseMessageUpdated(
        info: {
          "role": "command",
          "id": "backend-command",
          "sessionID": "session",
          "name": "review",
          "arguments": null,
          "origin": "automatic",
          "invocationId": null,
          "time": null,
        },
      ),
    );

    final outputs = await (relayOutput, debugOutput).wait;
    expect(timeline.initializationCount, 1);
    expect(timeline.canonicalizationCount, 1);
    expect(outputs.$1, same(outputs.$2));
    expect(outputs.$1, isA<PluginCommandTimelineCanonical>());
    expect(
      (outputs.$1 as PluginCommandTimelineCanonical).mutations,
      [isA<CommandTimelineEnvelopeUpdated>()],
    );
  });

  test("hydration failure still subscribes and passes through an unmatched command removal", () async {
    final db = createTestDatabase();
    final plugin = _EventPlugin();
    final repository = SessionRepository(
      plugin: plugin,
      sessionDao: db.sessionDao,
      projectsDao: db.projectsDao,
      pullRequestDao: db.pullRequestDao,
      unseenCalculator: const SessionUnseenCalculator(),
    );
    final mutationDispatcher = SessionMutationDispatcher(sessionRepository: repository);
    final timeline = _CountingTimelineService()
      ..initializationError = StateError("database unavailable")
      ..handlesCandidates = false;
    final listener = PluginCommandTimelineListener(
      sessionRepository: repository,
      enrichmentService: SessionEventEnrichmentService(
        sessionRepository: repository,
        sessionMutationDispatcher: mutationDispatcher,
        failureReporter: FakeFailureReporter(),
      ),
      timelineService: timeline,
    );
    addTearDown(() async {
      await listener.dispose();
      await mutationDispatcher.dispose();
      await plugin.close();
      await db.close();
    });
    await listener.start();
    final output = listener.outputs.first;
    const removal = BridgeSseMessageRemoved(sessionID: "session", messageID: "backend-command");

    plugin.add(removal);

    expect(
      await output,
      isA<PluginCommandTimelinePassthrough>().having((value) => value.event, "event", same(removal)),
    );
    expect(timeline.initializationCount, 1);
    expect(timeline.lastCandidate, isA<CommandMessageRemovedTimelineCandidate>());
  });
}

class _CountingTimelineService implements CommandTimelineService {
  int initializationCount = 0;
  int canonicalizationCount = 0;
  Object? initializationError;
  bool handlesCandidates = true;
  CommandTimelineCandidate? lastCandidate;

  @override
  Future<void> initialize() async {
    initializationCount++;
    final error = initializationError;
    if (error != null) throw error;
  }

  @override
  Future<CommandTimelineLiveResult> canonicalizePluginCandidate({required CommandTimelineCandidate candidate}) async {
    canonicalizationCount++;
    lastCandidate = candidate;
    if (!handlesCandidates) {
      return CommandTimelineLiveResult(handled: false, mutations: const []);
    }
    return CommandTimelineLiveResult(
      handled: true,
      mutations: [
        const CommandTimelineEnvelopeUpdated(
          info: Message.user(
            id: "command",
            sessionID: "session",
            agent: null,
            time: null,
          ),
        ),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EventPlugin implements NativeProjectsPluginApi {
  final StreamController<BridgeSseEvent> _events = StreamController<BridgeSseEvent>.broadcast(sync: true);

  @override
  String get id => "plugin";

  @override
  Stream<BridgeSseEvent> get events => _events.stream;

  void add(BridgeSseEvent event) => _events.add(event);

  Future<void> close() => _events.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
