import "package:sesori_shared/sesori_shared.dart";

import "http_method.dart";

class const PendingRoutedRequest({
  required final RouteIdentity routeIdentity,
  required final Future<RelayResponse> completion,
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
