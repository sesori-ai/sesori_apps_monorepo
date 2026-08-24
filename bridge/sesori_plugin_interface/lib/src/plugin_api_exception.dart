import "plugin_operation_exception.dart";

/// Thrown by plugin methods when the upstream API returns a non-success status.
///
/// Handlers and routers can catch this to forward the real HTTP status
/// instead of collapsing every failure to 502.
// ignore: no_slop_linter/prefer_required_named_parameters, public exception constructor
class PluginApiException(super.endpoint, int statusCode, {super.message, super.cause})
    extends PluginOperationException {
  this : super(statusCode: statusCode);

  /// The endpoint that failed; alias of [operation] for HTTP-backed plugins.
  String get endpoint => operation;

  @override
  // ignore: no_slop_linter/avoid_bang_operator, this constructor always supplies the base status code
  int get statusCode => super.statusCode!;

  @override
  String toString() {
    final detail = switch (message) {
      final message? when message.isNotEmpty => ": $message",
      _ => "",
    };
    final causeDetail = cause == null ? "" : " (cause: ${cause.toString()})";
    return "PluginApiException: $endpoint failed with status $statusCode$detail$causeDetail";
  }
}
