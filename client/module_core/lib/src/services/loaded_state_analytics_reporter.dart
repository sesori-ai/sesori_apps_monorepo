import "dart:async";

import "../foundation/models/product_analytics/product_analytics_event.dart";
import "../logging/logging.dart";
import "../repositories/models/analytics_delivery_result.dart";
import "product_analytics_service.dart";

enum LoadedStateAnalyticsClassification() { empty, nonEmpty }

enum _LoadedStateAnalyticsGuard() { ready, inFlight, consumed }

final class _LoadedStateOccurrence({
  required final LoadedStateAnalyticsClassification classification,
  required final ProductAnalyticsEvent event,
  required final DateTime occurredAtUtc,
});

class LoadedStateAnalyticsReporter({
  required final ProductAnalyticsService _productAnalyticsService,
  required final ProductAnalyticsEvent Function({required LoadedStateAnalyticsClassification classification})
  _eventForClassification,
  required final String _eventDescription,
}) {
  static LoadedStateAnalyticsReporter projectInventory({
    required ProductAnalyticsService productAnalyticsService,
  }) => LoadedStateAnalyticsReporter(
    productAnalyticsService: productAnalyticsService,
    eventForClassification: ({required classification}) => ProductAnalyticsEvent.projectInventoryLoaded(
      inventoryState: classification == LoadedStateAnalyticsClassification.empty
          ? AnalyticsInventoryState.empty
          : AnalyticsInventoryState.nonEmpty,
    ),
    eventDescription: "project inventory",
  );

  static LoadedStateAnalyticsReporter sessionDiff({
    required ProductAnalyticsService productAnalyticsService,
  }) => LoadedStateAnalyticsReporter(
    productAnalyticsService: productAnalyticsService,
    eventForClassification: ({required classification}) => ProductAnalyticsEvent.sessionDiffViewed(
      changeState: classification == LoadedStateAnalyticsClassification.empty
          ? AnalyticsChangeState.empty
          : AnalyticsChangeState.nonEmpty,
    ),
    eventDescription: "session diff",
  );

  StreamSubscription<bool>? _activationSubscription;

  _LoadedStateAnalyticsGuard _emptyGuard = _LoadedStateAnalyticsGuard.ready;
  _LoadedStateAnalyticsGuard _nonEmptyGuard = _LoadedStateAnalyticsGuard.ready;
  _LoadedStateOccurrence? _currentOccurrence;
  bool _closed = false;

  void reportLoaded({required bool isEmpty, required DateTime occurredAtUtc}) {
    if (_closed) return;
    _activationSubscription ??= _productAnalyticsService.stateStream
        .map((state) => state.isActive)
        .distinct()
        .where((isActive) => isActive)
        .listen((_) => _retryCurrentClassification());
    final classification = isEmpty
        ? LoadedStateAnalyticsClassification.empty
        : LoadedStateAnalyticsClassification.nonEmpty;
    final occurrence = _LoadedStateOccurrence(
      classification: classification,
      event: _eventForClassification(classification: classification),
      occurredAtUtc: occurredAtUtc,
    );
    _currentOccurrence = occurrence;
    _attempt(occurrence: occurrence);
  }

  void clearCurrentOccurrence() {
    _currentOccurrence = null;
  }

  void _retryCurrentClassification() {
    if (_closed) return;
    final occurrence = _currentOccurrence;
    if (occurrence != null) _attempt(occurrence: occurrence);
  }

  void _attempt({required _LoadedStateOccurrence occurrence}) {
    final isEmpty = occurrence.classification == LoadedStateAnalyticsClassification.empty;
    final guard = isEmpty ? _emptyGuard : _nonEmptyGuard;
    if (guard != _LoadedStateAnalyticsGuard.ready) return;
    final attemptedWhileActive = _productAnalyticsService.state.isActive;
    _setGuard(isEmpty: isEmpty, guard: _LoadedStateAnalyticsGuard.inFlight);

    unawaited(
      _productAnalyticsService
          .logEvent(event: occurrence.event, occurredAtUtc: occurrence.occurredAtUtc)
          .then<void>((result) {
            if (_closed) return;
            final consumed =
                result == AnalyticsDeliveryResult.acceptedBySdk ||
                (!isEmpty && result == AnalyticsDeliveryResult.deferredUntilPreference);
            _setGuard(
              isEmpty: isEmpty,
              guard: consumed ? _LoadedStateAnalyticsGuard.consumed : _LoadedStateAnalyticsGuard.ready,
            );
            final isActive = _productAnalyticsService.state.isActive;
            if (!consumed && isActive) logw("Failed to deliver $_eventDescription analytics event");
            if (!consumed && isEmpty && !attemptedWhileActive && isActive) {
              _retryCurrentClassification();
            }
          })
          .catchError((Object error, StackTrace stackTrace) {
            if (_closed) return;
            _setGuard(isEmpty: isEmpty, guard: _LoadedStateAnalyticsGuard.ready);
            logw("Failed to report $_eventDescription analytics event", error, stackTrace);
            if (isEmpty && !attemptedWhileActive && _productAnalyticsService.state.isActive) {
              _retryCurrentClassification();
            }
          }),
    );
  }

  void _setGuard({required bool isEmpty, required _LoadedStateAnalyticsGuard guard}) {
    if (isEmpty) {
      _emptyGuard = guard;
    } else {
      _nonEmptyGuard = guard;
    }
  }

  Future<void> close() async {
    _closed = true;
    await _activationSubscription?.cancel();
  }
}
