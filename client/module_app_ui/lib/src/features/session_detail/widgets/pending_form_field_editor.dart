import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../l10n/app_localizations.dart";

/// Keyed by the stable field ID so validation never replaces input ownership.
class const PendingFormFieldEditor({
  required final PendingFormField field,
  required final FormDraftValue? draft,
  required final FormValidationIssue? issue,
  required final bool editable,
  required final ValueChanged<FormDraftValue?> onChanged,
  super.key,
}) extends StatefulWidget {
  @override
  State<PendingFormFieldEditor> createState() => _PendingFormFieldEditorState();
}

class _PendingFormFieldEditorState() extends State<PendingFormFieldEditor> {
  late final _controller = TextEditingController(text: _text);
  final _focus = FocusNode();

  String get _text => switch (widget.draft) {
    FormInputDraft(:final text) => text,
    null || FormBooleanDraft() || FormChoiceDraft() || FormChoicesDraft() => "",
  };

  @override
  void didUpdateWidget(PendingFormFieldEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != _text) _controller.text = _text;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final field = widget.field;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(field.label, style: Theme.of(context).textTheme.titleSmall),
          Text(field.isRequired ? loc.mcpFormRequired : loc.mcpFormOptional),
          for (final hint in _hints(schema: field.schema, loc: loc)) Text(hint),
          if (field.description case final description?) Text(description),
          const SizedBox(height: PregoSpacing.sm),
          _input(context: context),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: widget.editable && widget.draft != null ? () => widget.onChanged(null) : null,
              child: Text(loc.mcpFormClearAnswer),
            ),
          ),
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(40),
            child: switch (widget.issue) {
              null => null,
              final issue => Semantics(
                liveRegion: true,
                child: Text(
                  _issueText(issue: issue, loc: loc),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            },
          ),
        ],
      ),
    );
  }

  Widget _input({required BuildContext context}) {
    final draft = widget.draft;
    return Material(
      type: MaterialType.transparency,
      child: switch (widget.field.schema) {
        FormSchemaUnknown() ||
        FormTextSchema(format: FormTextFormat.unknown) => Text(context.loc.mcpActionNotSupported),
        FormTextSchema(:final format) => _textInput(
          context: context,
          keyboard: switch (format) {
            FormTextFormat.email => TextInputType.emailAddress,
            FormTextFormat.uri => TextInputType.url,
            FormTextFormat.date || FormTextFormat.dateTime => TextInputType.datetime,
            FormTextFormat.plain || FormTextFormat.unknown => TextInputType.multiline,
          },
          multiline: format == FormTextFormat.plain,
        ),
        FormIntegerSchema() => _textInput(
          context: context,
          keyboard: const TextInputType.numberWithOptions(signed: true),
          multiline: false,
        ),
        FormNumberSchema() => _textInput(
          context: context,
          keyboard: const TextInputType.numberWithOptions(signed: true, decimal: true),
          multiline: false,
        ),
        FormBooleanSchema() => RadioGroup<bool>(
          groupValue: draft is FormBooleanDraft ? draft.value : null,
          onChanged: (value) => widget.onChanged(value == null ? null : FormBooleanDraft(value: value)),
          child: Column(
            children: [
              for (final value in [true, false])
                RadioListTile<bool>(
                  title: Text(value ? context.loc.mcpFormYes : context.loc.mcpFormNo),
                  value: value,
                  enabled: widget.editable,
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
        FormChoiceSchema(:final options) => RadioGroup<String>(
          groupValue: draft is FormChoiceDraft ? draft.optionId : null,
          onChanged: (value) => widget.onChanged(value == null ? null : FormChoiceDraft(optionId: value)),
          child: Column(
            children: [
              for (final option in options)
                RadioListTile<String>(
                  title: Text(option.label),
                  value: option.id,
                  enabled: widget.editable,
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
        FormChoicesSchema(:final options) => Column(
          children: [
            for (final option in options)
              CheckboxListTile(
                title: Text(option.label),
                value: draft is FormChoicesDraft && draft.optionIds.contains(option.id),
                contentPadding: EdgeInsets.zero,
                onChanged: widget.editable
                    ? (selected) {
                        final ids = draft is FormChoicesDraft ? {...draft.optionIds} : <String>{};
                        if (selected ?? false) {
                          ids.add(option.id);
                        } else {
                          ids.remove(option.id);
                        }
                        widget.onChanged(FormChoicesDraft(optionIds: ids.toList()));
                      }
                    : null,
              ),
          ],
        ),
      },
    );
  }

  Widget _textInput({required BuildContext context, required TextInputType keyboard, required bool multiline}) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: context.prego.colors.bgSurface1,
          borderRadius: BorderRadius.circular(PregoRadius.xl),
        ),
        child: Padding(
          padding: const EdgeInsets.all(PregoSpacing.md),
          child: Semantics(
            label: widget.field.label,
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              readOnly: !widget.editable,
              keyboardType: keyboard,
              minLines: 1,
              maxLines: multiline ? 5 : 1,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: context.loc.mcpFormAnswerHint,
              ),
              onChanged: (text) => widget.onChanged(FormInputDraft(text: text)),
            ),
          ),
        ),
      );
}

String _issueText({required FormValidationIssue issue, required AppLocalizations loc}) => switch (issue) {
  FormValidationIssue.required => loc.mcpFormIssueRequired,
  FormValidationIssue.invalidType => loc.mcpFormIssueType,
  FormValidationIssue.invalidChoice => loc.mcpFormIssueChoice,
  FormValidationIssue.outOfRange => loc.mcpFormIssueRange,
  FormValidationIssue.invalidLength => loc.mcpFormIssueLength,
  FormValidationIssue.invalidFormat => loc.mcpFormIssueFormat,
  FormValidationIssue.unknown => loc.mcpFormIssueUnknown,
};

List<String> _hints({required FormFieldSchema schema, required AppLocalizations loc}) => switch (schema) {
  FormIntegerSchema(:final minimum, :final maximum) => [
    loc.mcpFormWholeNumber,
    if (minimum != null) loc.mcpFormMinimum(minimum),
    if (maximum != null) loc.mcpFormMaximum(maximum),
  ],
  FormNumberSchema(:final minimum, :final maximum) => [
    if (minimum != null) loc.mcpFormMinimum(minimum),
    if (maximum != null) loc.mcpFormMaximum(maximum),
  ],
  FormTextSchema(:final minLength, :final maxLength) => [
    if (minLength != null) loc.mcpFormMinCharacters(minLength),
    if (maxLength != null) loc.mcpFormMaxCharacters(maxLength),
  ],
  FormChoicesSchema(:final minItems, :final maxItems) => [
    if (minItems != null) loc.mcpFormMinChoices(minItems),
    if (maxItems != null) loc.mcpFormMaxChoices(maxItems),
  ],
  FormSchemaUnknown() || FormBooleanSchema() || FormChoiceSchema() => [],
};
