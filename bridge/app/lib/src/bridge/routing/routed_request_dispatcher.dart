import "package:sesori_shared/sesori_shared.dart";

import "request_router.dart";
import "routed_request.dart";

sealed class const RoutedRequestDispatchResult();

final class const RoutedRequestAccepted({required final PendingRoutedRequest pendingRequest})
    extends RoutedRequestDispatchResult;

final class const RoutedRequestShutdownRejected({required final String requestId}) extends RoutedRequestDispatchResult {
  RelayResponse get response => RelayResponse(
    id: requestId,
    status: 503,
    headers: const {},
    body: "bridge is shutting down",
  );
}

/// Owns route acceptance and the completion barrier shared by every transport.
class RoutedRequestDispatcher({required final RequestRouter _router}) {
  final Set<Future<RoutedRequestOutcome>> _inFlightRoutes = <Future<RoutedRequestOutcome>>{};

  bool _accepting = true;
  Future<void>? _drainFuture;

  RoutedRequestDispatchResult dispatch({required RelayRequest request}) {
    if (!_accepting) {
      return RoutedRequestShutdownRejected(requestId: request.id);
    }

    final pendingRequest = _router.route(request: request);
    late final Future<RoutedRequestOutcome> trackedCompletion;
    trackedCompletion = pendingRequest.completion.whenComplete(() {
      _inFlightRoutes.remove(trackedCompletion);
    });
    _inFlightRoutes.add(trackedCompletion);

    return RoutedRequestAccepted(
      pendingRequest: PendingRoutedRequest(
        routeIdentity: pendingRequest.routeIdentity,
        completion: trackedCompletion,
      ),
    );
  }

  void beginShutdown() {
    _accepting = false;
  }

  Future<void> drain() => _drainFuture ??= _drain();

  Future<void> _drain() async {
    beginShutdown();
    await Future.wait(_inFlightRoutes.toList(growable: false));
  }
}
