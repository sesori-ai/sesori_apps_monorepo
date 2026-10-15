import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../runtime/plugin_runtime.dart";
import "mappers/plugin_form_mapper.dart";
import "models/session_operation.dart";
import "pending_interaction_support.dart";

class FormRepository({
  required final PluginRuntime _runtime,
  required final PendingInteractionSupport _pendingSupport,
}) {
  Future<List<PendingForm>> getPending({required String sessionId}) async {
    final binding = await _pendingSupport.requireBinding(
      sessionId: sessionId,
      operation: SessionOperation.getPendingForms,
    );
    return await _runtime.useIfActive(
          pluginId: binding.pluginId,
          operation: SessionOperation.getPendingForms,
          body: (plugin, _) async {
            if (plugin case final FormInteractionPluginApi api) {
              final tombstones = await _pendingSupport.readPendingTombstones(
                plugin: plugin,
                backendSessionId: binding.backendSessionId,
              );
              if (tombstones == null) return const <PendingForm>[];
              final forms = [
                for (final form in await api.getPendingForms(sessionId: binding.backendSessionId))
                  if (_pendingSupport.isVisible(
                    sessionId: form.sessionID,
                    displaySessionId: form.displaySessionId,
                    tombstones: tombstones,
                  ))
                    form,
              ];
              return await _pendingSupport.mapForms(pluginId: binding.pluginId, forms: forms);
            }
            return const <PendingForm>[];
          },
        ) ??
        const [];
  }

  Future<FormReplyResult> reply({required ReplyToFormRequest request}) => _withPendingForm(
    requestId: request.requestId,
    sessionId: request.sessionId,
    operation: SessionOperation.replyToForm,
    body: ({required api, required backendSessionId}) async {
      final values = <String, PluginFormValue>{};
      final errors = <String, FormValidationIssue>{};
      for (final entry in request.values.entries) {
        final value = entry.value.toPlugin();
        if (value == null) {
          errors[entry.key] = FormValidationIssue.invalidType;
        } else {
          values[entry.key] = value;
        }
      }
      if (errors.isNotEmpty) return FormValidationFailed(fieldErrors: errors);
      return switch (await api.replyToForm(requestId: request.requestId, sessionId: backendSessionId, values: values)) {
        PluginFormAccepted() => const FormReplyAccepted(),
        PluginFormAlreadySettled() => const FormAlreadySettled(),
        PluginFormValidationFailed(:final fieldErrors) => FormValidationFailed(
          fieldErrors: {
            for (final entry in fieldErrors.entries) entry.key: entry.value.toShared(),
          },
        ),
        PluginFormUnavailable() => _replyUnavailable(
          requestId: request.requestId,
          sessionId: backendSessionId,
          operation: SessionOperation.replyToForm,
        ),
      };
    },
  );

  Future<FormReplyResult> decline({required DeclineFormRequest request}) async {
    final choice = request.choice.toPlugin();
    if (choice == null) return const FormUnsupportedChoice();
    return await _withPendingForm(
      requestId: request.requestId,
      sessionId: request.sessionId,
      operation: SessionOperation.declineForm,
      body: ({required api, required backendSessionId}) async =>
          switch (await api.declineForm(requestId: request.requestId, sessionId: backendSessionId, choice: choice)) {
            PluginFormDismissalResult.accepted => const FormReplyAccepted(),
            PluginFormDismissalResult.alreadySettled => const FormAlreadySettled(),
            PluginFormDismissalResult.unavailable => _replyUnavailable(
              requestId: request.requestId,
              sessionId: backendSessionId,
              operation: SessionOperation.declineForm,
            ),
          },
    );
  }

  Future<FormReplyResult> _withPendingForm({
    required String requestId,
    required String sessionId,
    required SessionOperation operation,
    required Future<FormReplyResult> Function({required FormInteractionPluginApi api, required String backendSessionId})
    body,
  }) async {
    final binding = await _pendingSupport.requireBinding(sessionId: sessionId, operation: operation);
    return await _runtime.useIfActive(
          pluginId: binding.pluginId,
          operation: operation,
          body: (plugin, _) async {
            if (plugin case final FormInteractionPluginApi api) {
              final forms = await api.getPendingForms(sessionId: binding.backendSessionId);
              await _pendingSupport.throwIfMutationTargetTombstoned(
                interactionId: requestId,
                backendSessionId: binding.backendSessionId,
                operation: operation,
                plugin: plugin,
                readPending: () async => [
                  for (final form in forms)
                    (id: form.id, sessionID: form.sessionID, displaySessionId: form.displaySessionId),
                ],
              );
              if (!forms.any((form) => form.id == requestId && form.sessionID == binding.backendSessionId)) {
                return const FormAlreadySettled();
              }
              return await body(api: api, backendSessionId: binding.backendSessionId);
            }
            return const FormUnsupportedChoice();
          },
        ) ??
        const FormAlreadySettled();
  }

  Never _replyUnavailable({required String requestId, required String sessionId, required SessionOperation operation}) {
    Log.w("Native form response unavailable for $requestId in $sessionId (${operation.name})");
    throw PluginOperationException(operation.name, statusCode: 503, message: "native form response is unavailable");
  }
}
