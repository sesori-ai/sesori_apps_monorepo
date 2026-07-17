import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../bridge/repositories/session_repository.dart";
import "../bridge/services/command_timeline_mutation.dart";
import "../bridge/services/command_timeline_service.dart";
import "../bridge/services/session_event_enrichment_service.dart";

sealed class PluginCommandTimelineOutput {
  const PluginCommandTimelineOutput();
}

class PluginCommandTimelinePassthrough extends PluginCommandTimelineOutput {
  final BridgeSseEvent event;

  const PluginCommandTimelinePassthrough({required this.event});
}

class PluginCommandTimelineCanonical extends PluginCommandTimelineOutput {
  final List<CommandTimelineMutation> mutations;

  PluginCommandTimelineCanonical({required Iterable<CommandTimelineMutation> mutations})
    : mutations = List.unmodifiable(mutations);
}

/// Owns the single plugin-event trigger for command timeline canonicalization.
class PluginCommandTimelineListener {
  final SessionRepository _sessionRepository;
  final SessionEventEnrichmentService _enrichmentService;
  final CommandTimelineService _timelineService;
  final StreamController<PluginCommandTimelineOutput> _outputsController =
      StreamController<PluginCommandTimelineOutput>.broadcast(sync: true);
  StreamSubscription<void>? _subscription;
  Future<void>? _startFuture;

  PluginCommandTimelineListener({
    required SessionRepository sessionRepository,
    required SessionEventEnrichmentService enrichmentService,
    required CommandTimelineService timelineService,
  }) : _sessionRepository = sessionRepository,
       _enrichmentService = enrichmentService,
       _timelineService = timelineService;

  Stream<PluginCommandTimelineOutput> get outputs => _outputsController.stream;

  Future<void> start() => _startFuture ??= _start();

  Future<void> _start() async {
    try {
      await _timelineService.initialize();
    } on Object catch (error, stackTrace) {
      Log.w("Command timeline hydration failed; continuing with live plugin events", error, stackTrace);
    }
    _subscription = _sessionRepository.pluginEvents
        .asyncMap<void>(_process)
        .listen(
          (_) {},
          onError: _outputsController.addError,
        );
  }

  Future<void> _process(BridgeSseEvent rawEvent) async {
    final event = await _enrichmentService.enrich(rawEvent);
    if (event == null) return;
    final candidate = await _sessionRepository.mapPluginCommandCandidate(event: event);
    if (candidate == null) {
      _outputsController.add(PluginCommandTimelinePassthrough(event: event));
      return;
    }
    final result = await _timelineService.canonicalizePluginCandidate(candidate: candidate);
    if (!result.handled) {
      _outputsController.add(PluginCommandTimelinePassthrough(event: event));
    } else if (result.mutations.isNotEmpty) {
      _outputsController.add(PluginCommandTimelineCanonical(mutations: result.mutations));
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _outputsController.close();
  }
}
