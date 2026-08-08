import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";

import "http_method.dart";
import "models/restart_bridge_response.dart";

class PendingRoutedRequest {
  final RouteIdentity routeIdentity;
  final Future<RoutedRequestOutcome> completion;

  const PendingRoutedRequest({required this.routeIdentity, required this.completion});
}

sealed class RouteIdentity {
  const RouteIdentity();

  String get diagnosticLabel => switch (this) {
    MatchedRoute(:final method, :final pathTemplate) => "${method.diagnosticLabel} $pathTemplate",
    UnmatchedRoute(:final method) => "${method.diagnosticLabel} unmatched route",
    InvalidMethodRoute() => "invalid method",
    InvalidTargetRoute(:final method) => "${method.diagnosticLabel} invalid target",
  };
}

final class MatchedRoute extends RouteIdentity {
  final HttpMethod method;
  final String pathTemplate;

  const MatchedRoute({required this.method, required this.pathTemplate});
}

final class UnmatchedRoute extends RouteIdentity {
  final HttpMethod method;

  const UnmatchedRoute({required this.method});
}

final class InvalidMethodRoute extends RouteIdentity {
  const InvalidMethodRoute();
}

final class InvalidTargetRoute extends RouteIdentity {
  final HttpMethod method;

  const InvalidTargetRoute({required this.method});
}

sealed class RoutedRequestOutcome {
  const RoutedRequestOutcome();

  RelayResponse get response;
}

final class ResponseOnly extends RoutedRequestOutcome {
  @override
  final RelayResponse response;

  const ResponseOnly({required this.response});
}

final class RestartAccepted extends RoutedRequestOutcome {
  final String requestId;

  const RestartAccepted({required this.requestId});

  @override
  RelayResponse get response => RelayResponse(
    id: requestId,
    status: 200,
    headers: const {"content-type": "application/json"},
    body: jsonEncode(const RestartBridgeResponse(restarting: true)),
  );
}
