import "package:clock/clock.dart";
import "package:drift/native.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/bridge/foundation/uuid_v4_builder.dart";
import "package:sesori_bridge/src/bridge/repositories/command_invocation_repository.dart";
import "package:sesori_bridge/src/bridge/repositories/command_invocation_tracker.dart";
import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/services/command_dispatcher.dart";
import "package:sesori_bridge/src/bridge/services/command_timeline_service.dart";
import "package:sesori_bridge/src/bridge/services/session_event_enrichment_service.dart";
import "package:sesori_bridge/src/listeners/command_dispatch_outcome_listener.dart";
import "package:sesori_bridge/src/listeners/plugin_command_timeline_listener.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

AppDatabase createTestDatabase() => AppDatabase(NativeDatabase.memory());

class TestCommandStack {
  final CommandInvocationRepository repository;
  final CommandInvocationTracker tracker;
  final UuidV4Builder _uuidBuilder = _SequentialUuidV4Builder();

  factory TestCommandStack(AppDatabase db) {
    final repository = CommandInvocationRepository(dao: db.commandInvocationDao);
    final tracker = CommandInvocationTracker();
    return TestCommandStack._(
      repository: repository,
      tracker: tracker,
    );
  }

  TestCommandStack._({
    required this.repository,
    required this.tracker,
  });

  CommandDispatcher dispatcher({
    required BridgePluginApi plugin,
    required SessionRepository sessionRepository,
    Clock? clock,
  }) {
    return CommandDispatcher(
      sessionRepository: sessionRepository,
      invocationRepository: repository,
      uuidBuilder: _uuidBuilder,
      clock: clock ?? const Clock(),
    );
  }

  CommandTimelineService timelineService({required SessionRepository sessionRepository}) {
    return CommandTimelineService(
      sessionRepository: sessionRepository,
      invocationRepository: repository,
      tracker: tracker,
    );
  }
}

CommandTimelineService createTestCommandTimelineService(
  AppDatabase db, {
  required SessionRepository sessionRepository,
}) {
  return TestCommandStack(db).timelineService(sessionRepository: sessionRepository);
}

({
  CommandTimelineService timelineService,
  PluginCommandTimelineListener pluginListener,
  CommandDispatchOutcomeListener outcomeListener,
})
createTestCommandTimelineComposition({
  required AppDatabase database,
  required SessionRepository sessionRepository,
  required CommandDispatcher commandDispatcher,
  required SessionEventEnrichmentService enrichmentService,
}) {
  final timelineService = createTestCommandTimelineService(
    database,
    sessionRepository: sessionRepository,
  );
  return (
    timelineService: timelineService,
    pluginListener: PluginCommandTimelineListener(
      sessionRepository: sessionRepository,
      enrichmentService: enrichmentService,
      timelineService: timelineService,
    ),
    outcomeListener: CommandDispatchOutcomeListener(
      dispatcher: commandDispatcher,
      timelineService: timelineService,
    ),
  );
}

class _SequentialUuidV4Builder implements UuidV4Builder {
  int _nextInvocation = 0;

  @override
  String generate() {
    _nextInvocation++;
    return "00000000-0000-4000-8000-${_nextInvocation.toString().padLeft(12, "0")}";
  }
}
