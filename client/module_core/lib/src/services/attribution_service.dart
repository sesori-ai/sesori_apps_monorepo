import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../foundation/models/product_analytics/attribution_event.dart";
import "../foundation/models/product_analytics/product_analytics_event.dart";
import "../repositories/attribution_repository.dart";
import "../repositories/models/analytics_delivery_result.dart";

/// Owns every trigger dispatched to the independent platform attribution sink.
@lazySingleton
class AttributionService({
  required final AttributionRepository _repository,
  required final ConnectionService _connectionService,
}) {
  StreamSubscription<ConnectionStatus>? _connectionStatusSubscription;
  bool _started = false;
  bool _pendingFirstSessionRun = false;

  /// Starts the always-on bridge-pairing outcome listener.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _connectionStatusSubscription = _connectionService.status.listen(_onConnectionStatusChanged);
    if (_pendingFirstSessionRun) {
      _pendingFirstSessionRun = false;
      unawaited(_repository.logEvent(event: AttributionEvent.firstSessionRun));
    }
  }

  Future<AnalyticsDeliveryResult> reportAuthenticationCompleted({required AccountStatus accountStatus}) async {
    final results = <AnalyticsDeliveryResult>[];
    if (accountStatus == AccountStatus.created) {
      results.add(await _repository.logEvent(event: AttributionEvent.accountCreated));
    }
    results.add(await _repository.logEvent(event: AttributionEvent.accountLogin));

    return results.every((result) => result == AnalyticsDeliveryResult.acceptedBySdk)
        ? AnalyticsDeliveryResult.acceptedBySdk
        : AnalyticsDeliveryResult.failed;
  }

  /// Reuses the canonical product-event variants that define full activation.
  Future<void> reportProductOutcome({required ProductAnalyticsEvent event}) async {
    if (event is! SessionMessageSentEvent && event is! SessionCreatedWithMessageEvent) return;
    if (!_started) {
      _pendingFirstSessionRun = true;
      return;
    }
    await _repository.logEvent(event: AttributionEvent.firstSessionRun);
  }

  void _onConnectionStatusChanged(ConnectionStatus status) {
    if (status is ConnectionConnected) {
      unawaited(_repository.logEvent(event: AttributionEvent.bridgePaired));
    }
  }

  @disposeMethod
  Future<void> dispose() async {
    _pendingFirstSessionRun = false;
    await _connectionStatusSubscription?.cancel();
    _connectionStatusSubscription = null;
  }
}
