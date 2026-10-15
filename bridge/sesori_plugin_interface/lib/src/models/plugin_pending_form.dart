enum PluginFormTextFormat() {
  plain,
  email,
  uri,
  date,
  dateTime,
}

enum PluginFormDismissalChoice() {
  decline,
  cancel,
}

enum PluginFormDismissalResult() {
  accepted,
  alreadySettled,
  unavailable,
}

enum PluginFormValidationIssue() {
  required,
  invalidType,
  invalidChoice,
  outOfRange,
  invalidLength,
  invalidFormat,
}

final class const PluginFormChoice({required final String id, required final String label});

final class const PluginFormField({
  required final String id,
  required final String label,
  required final String? description,
  required final bool isRequired,
  required final PluginFormSchema schema,
});

sealed class const PluginFormSchema();

final class const PluginFormTextSchema({
  required final String? defaultValue,
  required final int? minLength,
  required final int? maxLength,
  required final PluginFormTextFormat format,
}) extends PluginFormSchema;

final class const PluginFormIntegerSchema({
  required final int? defaultValue,
  required final int? minimum,
  required final int? maximum,
}) extends PluginFormSchema;

final class const PluginFormNumberSchema({
  required final double? defaultValue,
  required final double? minimum,
  required final double? maximum,
}) extends PluginFormSchema;

final class const PluginFormBooleanSchema({required final bool? defaultValue}) extends PluginFormSchema;

final class PluginFormChoiceSchema({required List<PluginFormChoice> options, required final String? defaultOptionId})
    extends PluginFormSchema {
  final List<PluginFormChoice> options = List.unmodifiable(options);
}

final class PluginFormChoicesSchema({
  required List<PluginFormChoice> options,
  required List<String>? defaultOptionIds,
  required final int? minItems,
  required final int? maxItems,
}) extends PluginFormSchema {
  final List<PluginFormChoice> options = List.unmodifiable(options);
  final List<String>? defaultOptionIds = defaultOptionIds == null ? null : List.unmodifiable(defaultOptionIds);
}

sealed class const PluginFormValue();

final class const PluginFormTextValue({required final String value}) extends PluginFormValue;

final class const PluginFormIntegerValue({required final int value}) extends PluginFormValue;

final class const PluginFormNumberValue({required final double value}) extends PluginFormValue;

final class const PluginFormBooleanValue({required final bool value}) extends PluginFormValue;

final class const PluginFormChoiceValue({required final String optionId}) extends PluginFormValue;

final class PluginFormChoicesValue({required List<String> optionIds}) extends PluginFormValue {
  final List<String> optionIds = List.unmodifiable(optionIds);
}

/// Request-scoped fields and defaults never belong in broadcasts or persistence.
final class PluginPendingForm({
  required final String id,
  required final String sessionID,
  required final String? displaySessionId,
  required final String title,
  required final String message,
  required List<PluginFormField> fields,
}) {
  final List<PluginFormField> fields = List.unmodifiable(fields);
}

sealed class const PluginFormSubmissionResult();

final class const PluginFormAccepted() extends PluginFormSubmissionResult;

final class const PluginFormAlreadySettled() extends PluginFormSubmissionResult;

final class const PluginFormUnavailable() extends PluginFormSubmissionResult;

final class PluginFormValidationFailed({required Map<String, PluginFormValidationIssue> fieldErrors})
    extends PluginFormSubmissionResult {
  final Map<String, PluginFormValidationIssue> fieldErrors = Map.unmodifiable(fieldErrors);
}
