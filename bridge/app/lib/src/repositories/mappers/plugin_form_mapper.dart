import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

extension PluginPendingFormMapping on PluginPendingForm {
  PendingForm toShared({required String sessionId, required String? displaySessionId}) => PendingForm(
    id: id,
    sessionID: sessionId,
    displaySessionId: displaySessionId,
    title: title,
    message: message,
    fields: [for (final field in fields) field.toShared()],
  );
}

extension PluginFormFieldMapping on PluginFormField {
  PendingFormField toShared() => PendingFormField(
    id: id,
    label: label,
    description: description,
    isRequired: isRequired,
    schema: schema.toShared(),
  );
}

extension PluginFormChoiceMapping on PluginFormChoice {
  FormChoice toShared() => FormChoice(id: id, label: label);
}

extension PluginFormSchemaMapping on PluginFormSchema {
  FormFieldSchema toShared() => switch (this) {
    PluginFormTextSchema(:final defaultValue, :final minLength, :final maxLength, :final format) => FormTextSchema(
      defaultValue: defaultValue,
      minLength: minLength,
      maxLength: maxLength,
      format: switch (format) {
        PluginFormTextFormat.plain => FormTextFormat.plain,
        PluginFormTextFormat.email => FormTextFormat.email,
        PluginFormTextFormat.uri => FormTextFormat.uri,
        PluginFormTextFormat.date => FormTextFormat.date,
        PluginFormTextFormat.dateTime => FormTextFormat.dateTime,
      },
    ),
    PluginFormIntegerSchema(:final defaultValue, :final minimum, :final maximum) => FormIntegerSchema(
      defaultValue: defaultValue,
      minimum: minimum,
      maximum: maximum,
    ),
    PluginFormNumberSchema(:final defaultValue, :final minimum, :final maximum) => FormNumberSchema(
      defaultValue: defaultValue,
      minimum: minimum,
      maximum: maximum,
    ),
    PluginFormBooleanSchema(:final defaultValue) => FormBooleanSchema(defaultValue: defaultValue),
    PluginFormChoiceSchema(:final options, :final defaultOptionId) => FormChoiceSchema(
      options: options.map((option) => option.toShared()).toList(),
      defaultOptionId: defaultOptionId,
    ),
    PluginFormChoicesSchema(:final options, :final defaultOptionIds, :final minItems, :final maxItems) =>
      FormChoicesSchema(
        options: options.map((option) => option.toShared()).toList(),
        defaultOptionIds: defaultOptionIds,
        minItems: minItems,
        maxItems: maxItems,
      ),
  };
}

extension FormValueMapping on FormValue {
  PluginFormValue? toPlugin() => switch (this) {
    FormValueUnknown() => null,
    FormTextValue(:final value) => PluginFormTextValue(value: value),
    FormIntegerValue(:final value) => PluginFormIntegerValue(value: value),
    FormNumberValue(:final value) => PluginFormNumberValue(value: value),
    FormBooleanValue(:final value) => PluginFormBooleanValue(value: value),
    FormChoiceValue(:final optionId) => PluginFormChoiceValue(optionId: optionId),
    FormChoicesValue(:final optionIds) => PluginFormChoicesValue(optionIds: optionIds),
  };
}

extension FormDismissalChoiceMapping on FormDismissalChoice {
  PluginFormDismissalChoice? toPlugin() => switch (this) {
    FormDismissalChoice.unknown => null,
    FormDismissalChoice.decline => PluginFormDismissalChoice.decline,
    FormDismissalChoice.cancel => PluginFormDismissalChoice.cancel,
  };
}

extension PluginFormValidationIssueMapping on PluginFormValidationIssue {
  FormValidationIssue toShared() => switch (this) {
    PluginFormValidationIssue.required => FormValidationIssue.required,
    PluginFormValidationIssue.invalidType => FormValidationIssue.invalidType,
    PluginFormValidationIssue.invalidChoice => FormValidationIssue.invalidChoice,
    PluginFormValidationIssue.outOfRange => FormValidationIssue.outOfRange,
    PluginFormValidationIssue.invalidLength => FormValidationIssue.invalidLength,
    PluginFormValidationIssue.invalidFormat => FormValidationIssue.invalidFormat,
  };
}
