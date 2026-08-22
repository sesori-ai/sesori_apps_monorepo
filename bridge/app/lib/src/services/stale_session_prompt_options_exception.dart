import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginStaleOptionsException;

/// Bridge-owned prompt rejection after a plugin reports that the requested
/// agent, model, or variant is no longer offered.
class const StaleSessionPromptOptionsException({
  required final PluginStaleOptionsException cause,
  required final StackTrace causeStackTrace,
}) implements Exception {
  String? get message => cause.message;
}
