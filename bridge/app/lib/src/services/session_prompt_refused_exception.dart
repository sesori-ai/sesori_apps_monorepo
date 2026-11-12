import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginRefusalException;

/// Bridge-owned prompt rejection after a plugin refused the prompt with a
/// reason written for the user.
class const SessionPromptRefusedException({
  required final PluginRefusalException cause,
  required final StackTrace causeStackTrace,
}) implements Exception {
  String get userFacingReason => cause.userFacingReason;
}
