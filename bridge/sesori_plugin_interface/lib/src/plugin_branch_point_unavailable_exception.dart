import "plugin_operation_exception.dart";

/// The plugin cannot rewind or fork at the named message: it cannot map it to
/// a native boundary (legacy ids, compacted history), the message does not
/// open the backend's own turn, or the runtime is too old for the operation.
///
/// Bridge core may show [userFacingReason] in clients, so it must be a short
/// sentence the plugin wrote for the user: never transcript text, raw backend
/// output, stack traces or paths. Null when the plugin has no such sentence;
/// clients then show their own.
class const PluginBranchPointUnavailableException({
  required super.operation,
  required final String? userFacingReason,
  required super.cause,
}) extends PluginOperationException {
  this : super(statusCode: 409, message: userFacingReason);
}
