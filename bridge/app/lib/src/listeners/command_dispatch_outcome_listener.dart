import "dart:async";

import "../bridge/services/command_dispatch_outcome.dart";
import "../bridge/services/command_dispatcher.dart";
import "../bridge/services/command_timeline_mutation.dart";
import "../bridge/services/command_timeline_service.dart";

/// Owns the single command-dispatch-outcome trigger.
class CommandDispatchOutcomeListener {
  final CommandDispatcher _dispatcher;
  final CommandTimelineService _timelineService;
  final StreamController<List<CommandTimelineMutation>> _mutationsController =
      StreamController<List<CommandTimelineMutation>>.broadcast(sync: true);
  StreamSubscription<void>? _subscription;
  Future<void>? _startFuture;

  CommandDispatchOutcomeListener({
    required CommandDispatcher dispatcher,
    required CommandTimelineService timelineService,
  }) : _dispatcher = dispatcher,
       _timelineService = timelineService;

  Stream<List<CommandTimelineMutation>> get mutations => _mutationsController.stream;

  Future<void> start() => _startFuture ??= _start();

  Future<void> _start() async {
    await _timelineService.initialize();
    _subscription = _dispatcher.outcomes
        .asyncMap<void>(_process)
        .listen(
          (_) {},
          onError: _mutationsController.addError,
        );
  }

  Future<void> _process(CommandDispatchOutcome outcome) async {
    final result = await _timelineService.canonicalizeDispatchOutcome(outcome: outcome);
    if (result.mutations.isNotEmpty) _mutationsController.add(result.mutations);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _mutationsController.close();
  }
}
