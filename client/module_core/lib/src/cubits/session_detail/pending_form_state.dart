import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../foundation/models/form_draft_value.dart";

enum FormConnectionOwnership() {
  active,
  retired,
}

enum FormSubmissionIntent() {
  submit,
  decline,
  cancel,
}

enum FormRefusalReason() {
  unknownResponse,
  unsupportedChoice,
}

sealed class const PendingFormState();

final class const FormLoading() extends PendingFormState;
final class const FormDisconnected() extends PendingFormState;
final class const FormReadFailed({required final ApiError cause}) extends PendingFormState;
sealed class const FormSettled() extends PendingFormState;
final class const FormReplySent({required final FormSubmissionIntent intent}) extends FormSettled;
final class const FormNoLongerPending() extends FormSettled;

final class FormReady({
  required final PendingForm form,
  required Map<String, FormDraftValue> drafts,
  required final FormSubmission submission,
  required final FormConnectionOwnership connection,
}) extends PendingFormState {
  final Map<String, FormDraftValue> drafts = Map.unmodifiable(drafts);

  FormReady withDrafts({required Map<String, FormDraftValue> drafts, required FormSubmission submission}) =>
      FormReady(form: form, drafts: drafts, submission: submission, connection: connection);
  FormReady withSubmission({required FormSubmission submission}) =>
      FormReady(form: form, drafts: drafts, submission: submission, connection: connection);
  FormReady retire() =>
      FormReady(form: form, drafts: drafts, submission: submission, connection: FormConnectionOwnership.retired);
}

sealed class const FormSubmission();
final class const FormSubmissionIdle() extends FormSubmission;
final class const FormSubmitting({required final FormSubmissionIntent intent}) extends FormSubmission;

final class FormSubmissionInvalid({required Map<String, FormValidationIssue> fieldErrors}) extends FormSubmission {
  final Map<String, FormValidationIssue> fieldErrors = Map.unmodifiable(fieldErrors);
}

final class const FormSubmissionFailed({required final ApiError cause}) extends FormSubmission;
final class const FormSubmissionRefused({required final FormRefusalReason reason}) extends FormSubmission;
