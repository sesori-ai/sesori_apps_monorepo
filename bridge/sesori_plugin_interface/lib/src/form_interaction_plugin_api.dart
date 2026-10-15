import "models/plugin_pending_form.dart";

/// Optional native form support, backed by the plugin's existing pending owner.
abstract interface class FormInteractionPluginApi() {
  Future<List<PluginPendingForm>> getPendingForms({required String sessionId});

  Future<PluginFormSubmissionResult> replyToForm({
    required String requestId,
    required String sessionId,
    required Map<String, PluginFormValue> values,
  });

  Future<PluginFormDismissalResult> declineForm({
    required String requestId,
    required String sessionId,
    required PluginFormDismissalChoice choice,
  });
}
