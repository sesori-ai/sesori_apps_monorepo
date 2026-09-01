import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:singular_flutter_sdk/events.dart";

import "../singular_attribution_startup.dart";
import "singular_static_adapter.dart";

@LazySingleton(as: AttributionClient)
class SingularAttributionClient({
  required final SingularAttributionStartup _startup,
  required final SingularStaticAdapter _singular,
  required final SecureStorage _storage,
}) implements AttributionClient {
  static const _bridgePairedStorageKey = "singular_attribution_bridge_paired_v1";
  static const _firstSessionRunStorageKey = "singular_attribution_first_session_run_v1";
  static const _storedClaim = "true";

  final Set<AttributionEvent> _claimedEvents = {};
  final Map<AttributionEvent, Future<bool>> _activeClaims = {};

  @override
  Future<void> logEvent({required AttributionEvent event}) async {
    final eventName = switch (event) {
      AttributionEvent.accountCreated => Events.sngCompleteRegistration,
      AttributionEvent.accountLogin => Events.sngLogin,
      AttributionEvent.bridgePaired => "bridge_paired",
      AttributionEvent.firstSessionRun => "first_session_run",
    };
    if (!_startup.activateAfterInteractiveAuthentication()) return;

    final oneShotStorageKey = switch (event) {
      AttributionEvent.bridgePaired => _bridgePairedStorageKey,
      AttributionEvent.firstSessionRun => _firstSessionRunStorageKey,
      AttributionEvent.accountCreated || AttributionEvent.accountLogin => null,
    };
    if (oneShotStorageKey != null && !await _claimOnce(event: event, storageKey: oneShotStorageKey)) {
      return;
    }
    _singular.event(eventName: eventName);
  }

  Future<bool> _claimOnce({required AttributionEvent event, required String storageKey}) async {
    final activeClaim = _activeClaims[event];
    if (activeClaim != null) {
      await activeClaim;
      return false;
    }
    if (_claimedEvents.contains(event)) return false;

    late final Future<bool> claim;
    claim = _persistClaim(event: event, storageKey: storageKey).whenComplete(() {
      if (identical(_activeClaims[event], claim)) _activeClaims.remove(event);
    });
    _activeClaims[event] = claim;
    return await claim;
  }

  Future<bool> _persistClaim({required AttributionEvent event, required String storageKey}) async {
    _claimedEvents.add(event);
    try {
      if (await _storage.read(key: storageKey) == _storedClaim) return false;
      await _storage.write(key: storageKey, value: _storedClaim);
      return true;
    } on Object catch (error, stackTrace) {
      logw("Failed to persist one-time Singular attribution event (${event.name})", error, stackTrace);
      return false;
    }
  }
}
