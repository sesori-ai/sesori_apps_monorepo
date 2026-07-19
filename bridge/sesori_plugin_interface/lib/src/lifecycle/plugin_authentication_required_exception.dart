import "../plugin_operation_exception.dart";

/// Authoritative plugin-owned signal that backend authentication is no longer
/// usable. Bridge core reacts to this type without parsing backend error text.
class PluginAuthenticationRequiredException extends PluginOperationException {
  const PluginAuthenticationRequiredException(
    super.operation, {
    required this.actionHint,
    super.message,
    super.cause,
  }) : super(statusCode: 503);

  final String? actionHint;
}
