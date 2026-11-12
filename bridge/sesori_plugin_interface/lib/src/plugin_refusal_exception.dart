import "plugin_operation_exception.dart";

/// The backend refused the operation for a reason the plugin can explain to
/// the user, such as a conflict with their harness configuration.
///
/// Bridge core may show [userFacingReason] in clients, so it must be a short
/// sentence the plugin wrote for the user: never raw backend output, stack
/// traces, paths, or prompt content. Failures without such a sentence throw a
/// plain [PluginOperationException] instead.
class const PluginRefusalException(
  super.operation, {
  required final String userFacingReason,
  required super.cause,
}) extends PluginOperationException {
  this : super(statusCode: 409, message: userFacingReason);
}
