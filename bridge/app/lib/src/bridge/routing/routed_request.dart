import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";

import "http_method.dart";
import "models/restart_bridge_response.dart";

class const PendingRoutedRequest({required this.routeIdentity, required this.completion}) {
  final RouteIdentity routeIdentity;
  final Future<RoutedRequestOutcome> completion;
}

sealed class const RouteIdentity() {
  String get diagnosticLabel => switch (this) {
    MatchedRoute(:final method, :final pathTemplate) => "${method.diagnosticLabel} $pathTemplate",
    UnmatchedRoute(:final method) => "${method.diagnosticLabel} unmatched route",
    InvalidMethodRoute() => "invalid method",
    InvalidTargetRoute(:final method) => "${method.diagnosticLabel} invalid target",
  };
}

final class const MatchedRoute({required this.method, required this.pathTemplate}) extends RouteIdentity {
  final HttpMethod method;
  final String pathTemplate;
}

final class const UnmatchedRoute({required this.method}) extends RouteIdentity {
  final HttpMethod method;
}

final class const InvalidMethodRoute() extends RouteIdentity;

final class const InvalidTargetRoute({required this.method}) extends RouteIdentity {
  final HttpMethod method;
}

sealed class const RoutedRequestOutcome() {
  RelayResponse get response;
}

final class const ResponseOnly({required this.response}) extends RoutedRequestOutcome {
  @override
  final RelayResponse response;
}

final class const RestartAccepted({required this.requestId}) extends RoutedRequestOutcome {
  final String requestId;

  @override
  RelayResponse get response => RelayResponse(
    id: requestId,
    status: 200,
    headers: const {"content-type": "application/json"},
    body: jsonEncode(const RestartBridgeResponse(restarting: true)),
  );
}
