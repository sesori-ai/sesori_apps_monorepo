import "plugin_operation_exception.dart";

/// The request named an agent, model, or variant the plugin no longer offers,
/// typically because the caller's cached session options predate a plugin or
/// backend change. Plugins throw this for every unsupported selection; the
/// prompt path turns it into a recognizable rejection so the client refreshes
/// its options and resends, and bridge core reacts to the type without
/// parsing backend error text.
class const PluginStaleOptionsException(
  super.operation, {
  super.message,
  super.cause,
}) extends PluginOperationException {
  this : super(statusCode: 409);
}
