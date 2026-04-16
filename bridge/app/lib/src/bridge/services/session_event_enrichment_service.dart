import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/session_repository.dart";

class SessionEventEnrichmentService {
  final SessionRepository _sessionRepository;
  final FailureReporter _failureReporter;

  SessionEventEnrichmentService({
    required SessionRepository sessionRepository,
    required FailureReporter failureReporter,
  }) : _sessionRepository = sessionRepository,
       _failureReporter = failureReporter;

  Future<BridgeSseEvent> enrich(BridgeSseEvent event) async {
    try {
      return switch (event) {
        BridgeSseSessionCreated(:final info) => BridgeSseSessionCreated(
          info: (await _sessionRepository.enrichSessionJson(sessionJson: info)).toJson(),
        ),
        BridgeSseSessionUpdated(:final info) => BridgeSseSessionUpdated(
          info: (await _sessionRepository.enrichSessionJson(sessionJson: info)).toJson(),
        ),
        _ => event,
      };
    } catch (e, st) {
      Log.w("[sse] failed to enrich ${event.runtimeType}: $e");
      try {
        await _failureReporter.recordFailure(
          error: e,
          stackTrace: st,
          uniqueIdentifier: "bridge.sse.enrichment",
          fatal: false,
          reason: "failed to enrich plugin SSE event",
          information: [event.runtimeType],
        );
      } catch (reportError, reportStackTrace) {
        Log.w("[sse] failed to report enrichment failure: $reportError\n$reportStackTrace");
      }
      return event;
    }
  }
}
