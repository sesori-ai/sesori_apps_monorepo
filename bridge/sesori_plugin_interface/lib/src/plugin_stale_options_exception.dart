import "plugin_operation_exception.dart";

/// The send named an agent, model, or variant the plugin no longer offers,
/// typically because the caller's cached session options predate a plugin or
/// backend change. Handlers map this type to a recognizable response so the
/// client refreshes its options and resends with a supported selection;
/// bridge core reacts to the type without parsing backend error text.
class const PluginStaleOptionsException(
  super.operation, {
  super.message,
  super.cause,
}) extends PluginOperationException {
  this : super(statusCode: 409);
}
