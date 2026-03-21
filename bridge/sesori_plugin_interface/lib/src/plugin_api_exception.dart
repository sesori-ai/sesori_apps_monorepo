/// Thrown by plugin methods when the upstream API returns a non-success status.
///
/// Handlers and routers can catch this to forward the real HTTP status
/// instead of collapsing every failure to 502.
class PluginApiException implements Exception {
  final int statusCode;
  final String endpoint;

  PluginApiException(this.endpoint, this.statusCode);

  @override
  String toString() => "PluginApiException: $endpoint failed with status $statusCode";
}
