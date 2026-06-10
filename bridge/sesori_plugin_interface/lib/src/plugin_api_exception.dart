import "plugin_operation_exception.dart";

/// Thrown by plugin methods when the upstream API returns a non-success status.
///
/// Handlers and routers can catch this to forward the real HTTP status
/// instead of collapsing every failure to 502.
class PluginApiException extends PluginOperationException {
  PluginApiException(super.endpoint, int statusCode) : super(statusCode: statusCode);

  /// The endpoint that failed; alias of [operation] for HTTP-backed plugins.
  String get endpoint => operation;

  @override
  int get statusCode => super.statusCode!;

  @override
  String toString() => "PluginApiException: $endpoint failed with status $statusCode";
}
