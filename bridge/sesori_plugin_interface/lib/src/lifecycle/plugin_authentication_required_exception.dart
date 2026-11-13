import "../plugin_operation_exception.dart";

/// How the user restores access after [PluginAuthenticationRequiredException].
enum PluginAuthenticationRecovery() {
  /// Logging in to the backend, from Sesori or on the bridge machine, restores
  /// access. Bridge core reports setup as authentication required.
  login,

  /// Credentials live outside the backend's own login, for example in a
  /// gateway that owns authentication, so a login cannot help. The user fixes
  /// them there and refreshes setup. Bridge core reports setup as unavailable.
  externalConfiguration,
}

/// Authoritative plugin-owned signal that backend authentication is no longer
/// usable. Bridge core reacts to this type without parsing backend error text.
class const PluginAuthenticationRequiredException({
  required super.operation,
  required final String? actionHint,
  required final PluginAuthenticationRecovery recovery,
  super.message,
  super.cause,
}) extends PluginOperationException {
  this : super(statusCode: 503);
}
