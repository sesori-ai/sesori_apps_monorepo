/// Thrown by plugin methods when the upstream API returns a non-success status.
///
/// Handlers and routers can catch this to forward the real HTTP status
/// instead of collapsing every failure to 502.
class PluginApiException implements Exception {
  final int statusCode;
  final String endpoint;

  /// Optional upstream failure detail (e.g. the upstream response body) so
  /// logs surface the actual reason instead of just a status code.
  final String? detail;

  PluginApiException(this.endpoint, this.statusCode, {this.detail});

  @override
  String toString() {
    final detailSuffix = detail == null || detail!.isEmpty ? "" : ": $detail";
    return "PluginApiException: $endpoint failed with status $statusCode$detailSuffix";
  }
}
