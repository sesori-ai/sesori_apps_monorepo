import "plugin_operation_exception.dart";

/// The backend refuses to restore a stored session as saved, so its history
/// cannot be replayed and the session cannot be continued. The required
/// [message] is plugin-supplied, user-presentable, and privacy-safe; bridge
/// core shows it as-is and reacts to the type without parsing backend error
/// text. The status code stays unset, so an instance that escapes still maps
/// to a 502.
class const PluginSessionUnrestorableException(
  super.operation, {
  required String super.message,
  super.cause,
}) extends PluginOperationException;
