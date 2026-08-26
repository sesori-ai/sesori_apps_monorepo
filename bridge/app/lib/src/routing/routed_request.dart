import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";

import "http_method.dart";
import "models/restart_bridge_response.dart";

sealed class const RoutedRequestContext();

final class const LocalRoutedRequestContext() extends RoutedRequestContext;

final class const RelayRoutedRequestContext({
  required final int connectionId,
  required final Object connectionIncarnation,
}) extends RoutedRequestContext;

class const PendingRoutedRequest({
  required final RouteIdentity routeIdentity,
  required final Future<RoutedRequestOutcome> completion,
});

sealed class const RouteIdentity() {
  String get diagnosticLabel => switch (this) {
    MatchedRoute(:final method, :final pathTemplate) => "${method.diagnosticLabel} $pathTemplate",
    UnmatchedRoute(:final method) => "${method.diagnosticLabel} unmatched route",
    InvalidMethodRoute() => "invalid method",
    InvalidTargetRoute(:final method) => "${method.diagnosticLabel} invalid target",
  };
}

final class const MatchedRoute({required final HttpMethod method, required final String pathTemplate})
    extends RouteIdentity;

final class const UnmatchedRoute({required final HttpMethod method}) extends RouteIdentity;

final class const InvalidMethodRoute() extends RouteIdentity;

final class const InvalidTargetRoute({required final HttpMethod method}) extends RouteIdentity;

sealed class const RoutedRequestOutcome() {
  RelayResponse get response;
}

final class const ResponseOnly({@override required final RelayResponse response}) extends RoutedRequestOutcome;

final class const RestartAccepted({required final String requestId}) extends RoutedRequestOutcome {
  @override
  RelayResponse get response => RelayResponse(
    id: requestId,
    status: 200,
    headers: const {"content-type": "application/json"},
    body: jsonEncode(const RestartBridgeResponse(restarting: true)),
  );
}
