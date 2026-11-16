import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginStaleOptionsException;
import "package:sesori_shared/sesori_shared.dart" show PromptModel, SessionVariant;

/// Bridge-owned prompt rejection after a plugin reports that the requested
/// agent, model, or variant is no longer offered.
///
/// It keeps the catalog ids the bridge sent so its log line names them; the
/// plugin's [cause] says which kind it refused.
class const StaleSessionPromptOptionsException({
  required final PluginStaleOptionsException cause,
  required final StackTrace causeStackTrace,
  required final String? agent,
  required final PromptModel? model,
  required final SessionVariant? variant,
}) implements Exception {
  String? get message => cause.message;

  @override
  String toString() {
    final sentModel = switch (model) {
      PromptModel(:final providerID, :final modelID) => "$providerID/$modelID",
      null => "unset",
    };
    return "StaleSessionPromptOptionsException: the harness refused the sent options as stale "
        "(agent ${agent ?? 'unset'}, model $sentModel, variant ${variant?.id ?? 'unset'}): $cause";
  }
}
