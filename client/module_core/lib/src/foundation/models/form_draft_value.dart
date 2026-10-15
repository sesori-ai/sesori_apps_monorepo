/// In-memory editor values. Absence from the draft map means unanswered.
/// Raw numeric text remains editable until a submission can parse it faithfully.
sealed class const FormDraftValue();

final class const FormInputDraft({required final String text}) extends FormDraftValue;

final class const FormBooleanDraft({required final bool value}) extends FormDraftValue;

final class const FormChoiceDraft({required final String optionId}) extends FormDraftValue;

final class FormChoicesDraft({required List<String> optionIds}) extends FormDraftValue {
  final List<String> optionIds = List.unmodifiable(optionIds);
}
