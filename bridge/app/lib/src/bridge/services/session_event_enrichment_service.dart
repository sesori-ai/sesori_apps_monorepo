import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../repositories/session_repository.dart";

class SessionEventEnrichmentService {
  final SessionRepository _sessionRepository;

  SessionEventEnrichmentService({required SessionRepository sessionRepository})
    : _sessionRepository = sessionRepository;

  Future<BridgeSseEvent> enrich(BridgeSseEvent event) async {
    return switch (event) {
      BridgeSseSessionCreated(:final info) => BridgeSseSessionCreated(
        info: (await _sessionRepository.enrichSessionJson(sessionJson: info)).toJson(),
      ),
      BridgeSseSessionUpdated(:final info) => BridgeSseSessionUpdated(
        info: (await _sessionRepository.enrichSessionJson(sessionJson: info)).toJson(),
      ),
      _ => event,
    };
  }
}
