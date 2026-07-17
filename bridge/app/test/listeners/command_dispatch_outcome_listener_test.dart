import "dart:async";

import "package:sesori_bridge/src/bridge/services/command_dispatch_outcome.dart";
import "package:sesori_bridge/src/bridge/services/command_dispatcher.dart";
import "package:sesori_bridge/src/bridge/services/command_timeline_mutation.dart";
import "package:sesori_bridge/src/bridge/services/command_timeline_service.dart";
import "package:sesori_bridge/src/listeners/command_dispatch_outcome_listener.dart";
import "package:test/test.dart";

void main() {
  test("start is idempotent and outputs neutral command mutations", () async {
    final dispatcher = _FakeCommandDispatcher();
    final timeline = _FakeCommandTimelineService();
    final listener = CommandDispatchOutcomeListener(
      dispatcher: dispatcher,
      timelineService: timeline,
    );
    addTearDown(() async {
      await listener.dispose();
      await dispatcher.close();
    });

    await listener.start();
    await listener.start();
    final output = listener.mutations.first;
    dispatcher.add(
      RejectedCommandDispatchOutcome(
        pluginId: "plugin",
        sessionId: "session",
        invocationId: "invocation",
        error: StateError("rejected"),
        stackTrace: StackTrace.current,
      ),
    );

    expect(await output, [isA<CommandTimelinePartRemoved>()]);
    expect(timeline.initializationCount, 1);
    expect(timeline.canonicalizationCount, 1);
  });
}

class _FakeCommandDispatcher implements CommandDispatcher {
  final StreamController<CommandDispatchOutcome> _outcomes = StreamController<CommandDispatchOutcome>.broadcast(
    sync: true,
  );

  @override
  Stream<CommandDispatchOutcome> get outcomes => _outcomes.stream;

  void add(CommandDispatchOutcome outcome) => _outcomes.add(outcome);

  Future<void> close() => _outcomes.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCommandTimelineService implements CommandTimelineService {
  int initializationCount = 0;
  int canonicalizationCount = 0;

  @override
  Future<void> initialize() async {
    initializationCount++;
  }

  @override
  Future<CommandTimelineLiveResult> canonicalizeDispatchOutcome({required CommandDispatchOutcome outcome}) async {
    canonicalizationCount++;
    return CommandTimelineLiveResult(
      handled: true,
      mutations: const [
        CommandTimelinePartRemoved(
          sessionId: "session",
          messageId: "message",
          partId: "part",
        ),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
