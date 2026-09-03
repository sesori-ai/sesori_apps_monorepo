import "plugin_operation_exception.dart";

/// The send named an agent, model, variant, or command the plugin no longer
/// offers, typically because the caller's cached session options predate a
/// plugin or backend change. Handlers map this type to a recognizable response
/// so the client refreshes its options and either resends with a supported
/// selection or surfaces an unavailable command; bridge core reacts to the
/// type without parsing backend error text.
class const PluginStaleOptionsException(
  super.operation, {
  super.message,
  super.cause,
}) extends PluginOperationException {
  this : super(statusCode: 409);
}
