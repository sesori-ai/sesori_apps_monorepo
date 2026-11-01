import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

/// The desktop's analytics sink. It only streams product events to whoever
/// listens to [events]; delivery policy stays in `module_desktop_core`.
@lazySingleton
class DesktopAnalyticsClient() implements AnalyticsClient, DesktopProductEventSource {
  // Single-subscription, so events logged before the listener arrives wait for
  // it. Synchronous, so from then on the listener runs in the caller's stack and
  // sees the account that was current when the event was logged.
  // ponytail: unbounded buffer, but it holds zero events in production because
  // `main.dart` starts the delivery service first. Bound it if a launch path ever
  // skips `start()`.
  final StreamController<ProductAnalyticsEnvelope> _events = StreamController<ProductAnalyticsEnvelope>(sync: true);

  @override
  Stream<ProductAnalyticsEnvelope> get events => _events.stream;

  @override
  Future<void> logProductEvent({required ProductAnalyticsEnvelope envelope, required String userKey}) async {
    if (!_events.isClosed) _events.add(envelope);
  }

  @override
  Future<void> logInstallationEvent({required InstallationAnalyticsEvent event}) async {}

  @override
  Future<void> activateAfterInteractiveAuthentication() async {}

  /// Doesn't wait for the close: with no listener it never completes, which would
  /// hang `getIt.reset()`.
  @disposeMethod
  Future<void> dispose() async {
    unawaited(_events.close());
  }
}
