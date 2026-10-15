import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../foundation/models/form_draft_value.dart";
import "../repositories/session_repository.dart";

/// Converts editable drafts without owning the native request's lifetime.
@lazySingleton
class PendingFormService({required final SessionRepository _repository}) {
  Future<PendingForm?> read({required String requestId, required String sessionId}) async {
    switch (await _repository.getPendingForms(sessionId: sessionId)) {
      case SuccessResponse(:final data):
        return data.data.where((form) => form.id == requestId && form.sessionID == sessionId).firstOrNull;
      case ErrorResponse(:final error):
        throw error;
    }
  }

  bool supportsSubmission({required PendingForm form}) => form.fields.every(
    (field) => switch (field.schema) {
      FormSchemaUnknown() => false,
      FormTextSchema(:final format) => format != FormTextFormat.unknown,
      FormIntegerSchema() ||
      FormNumberSchema() ||
      FormBooleanSchema() ||
      FormChoiceSchema() ||
      FormChoicesSchema() => true,
    },
  );

  Map<String, FormDraftValue> initialDrafts({required PendingForm form}) => Map.unmodifiable({
    for (final field in form.fields) field.id: ?_defaultDraft(schema: field.schema),
  });

  Future<FormReplyResult> submit({required PendingForm form, required Map<String, FormDraftValue> drafts}) async {
    if (!supportsSubmission(form: form)) return const FormUnsupportedChoice();
    final values = <String, FormValue>{};
    final errors = <String, FormValidationIssue>{};
    for (final field in form.fields) {
      final draft = drafts[field.id];
      if (draft == null) {
        if (field.isRequired) errors[field.id] = FormValidationIssue.required;
      } else {
        final value = _typedValue(schema: field.schema, draft: draft);
        if (value == null) {
          errors[field.id] = FormValidationIssue.invalidType;
        } else {
          values[field.id] = value;
        }
      }
    }
    if (errors.isNotEmpty) return FormValidationFailed(fieldErrors: errors);
    return switch (await _repository.replyToForm(
      request: ReplyToFormRequest(
        requestId: form.id,
        sessionId: form.sessionID,
        values: values,
      ),
    )) {
      SuccessResponse(:final data) => data,
      ErrorResponse(:final error) => throw error,
    };
  }

  Future<FormReplyResult> decline({required PendingForm form, required FormDismissalChoice choice}) async {
    if (choice == FormDismissalChoice.unknown) return const FormUnsupportedChoice();
    return switch (await _repository.declineForm(
      request: DeclineFormRequest(
        requestId: form.id,
        sessionId: form.sessionID,
        choice: choice,
      ),
    )) {
      SuccessResponse(:final data) => data,
      ErrorResponse(:final error) => throw error,
    };
  }

  FormDraftValue? _defaultDraft({required FormFieldSchema schema}) => switch (schema) {
    FormSchemaUnknown() => null,
    FormTextSchema(:final defaultValue) => defaultValue == null ? null : FormInputDraft(text: defaultValue),
    FormIntegerSchema(:final defaultValue) =>
      defaultValue == null ? null : FormInputDraft(text: defaultValue.toString()),
    FormNumberSchema(:final defaultValue) =>
      defaultValue == null ? null : FormInputDraft(text: defaultValue.toString()),
    FormBooleanSchema(:final defaultValue) => defaultValue == null ? null : FormBooleanDraft(value: defaultValue),
    FormChoiceSchema(:final defaultOptionId) =>
      defaultOptionId == null ? null : FormChoiceDraft(optionId: defaultOptionId),
    FormChoicesSchema(:final defaultOptionIds) =>
      defaultOptionIds == null ? null : FormChoicesDraft(optionIds: defaultOptionIds),
  };

  FormValue? _typedValue({required FormFieldSchema schema, required FormDraftValue draft}) => switch (schema) {
    FormSchemaUnknown() => null,
    FormTextSchema() => draft is FormInputDraft ? FormTextValue(value: draft.text) : null,
    FormIntegerSchema() => draft is FormInputDraft ? _integer(text: draft.text) : null,
    FormNumberSchema() => draft is FormInputDraft ? _number(text: draft.text) : null,
    FormBooleanSchema() => draft is FormBooleanDraft ? FormBooleanValue(value: draft.value) : null,
    FormChoiceSchema() => draft is FormChoiceDraft ? FormChoiceValue(optionId: draft.optionId) : null,
    FormChoicesSchema() => draft is FormChoicesDraft ? FormChoicesValue(optionIds: draft.optionIds) : null,
  };

  FormIntegerValue? _integer({required String text}) {
    final value = int.tryParse(text);
    return value == null ? null : FormIntegerValue(value: value);
  }

  FormNumberValue? _number({required String text}) {
    final value = double.tryParse(text);
    return value == null || !value.isFinite ? null : FormNumberValue(value: value);
  }
}
