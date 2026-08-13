import "../plugin_operation_exception.dart";

/// Authoritative plugin-owned signal that backend authentication is no longer
/// usable. Bridge core reacts to this type without parsing backend error text.
class const PluginAuthenticationRequiredException(
  super.operation, {
  required final String? actionHint,
  super.message,
  super.cause,
}) extends PluginOperationException {
  this : super(statusCode: 503);
}
