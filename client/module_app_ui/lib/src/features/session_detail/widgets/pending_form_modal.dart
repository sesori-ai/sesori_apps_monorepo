import "dart:math" as math;

import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../l10n/app_localizations.dart";
import "pending_form_field_editor.dart";
import "pending_request_auto_dismiss.dart";

typedef PendingFormCubitFactory = PendingFormCubit Function({required String requestId, required String sessionId});

Future<void> showPendingFormModal({
  required BuildContext context,
  required String requestId,
  required String sessionId,
  required PendingFormCubitFactory createCubit,
  required Stream<bool> isPendingStream,
  required bool Function() isPending,
  required VoidCallback onSettled,
  required VoidCallback onPendingDismissed,
  required VoidCallback onCancelUnavailable,
}) {
  final topInset = MediaQuery.paddingOf(context).top;
  return showPregoModalRoute<void>(
    context: context,
    builder: (_) => PendingRequestAutoDismiss(
      isPendingStream: isPendingStream,
      isPending: isPending,
      onResolved: onPendingDismissed,
      child: BlocProvider(
        create: (_) => createCubit(requestId: requestId, sessionId: sessionId),
        child: PendingFormModal(topInset: topInset, onSettled: onSettled, onCancelUnavailable: onCancelUnavailable),
      ),
    ),
  );
}

class const PendingFormModal({
  required final double topInset,
  required final VoidCallback onSettled,
  required final VoidCallback onCancelUnavailable,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocConsumer<PendingFormCubit, PendingFormState>(
    // Keep the form intact during its closing transition; settlement is owned
    // by the pending-list listener rather than an empty replacement frame.
    buildWhen: (_, current) => current is! FormSettled,
    listener: (_, state) {
      if (state is FormSettled) onSettled();
    },
    builder: (context, state) {
      final loc = context.loc;
      final cubit = context.read<PendingFormCubit>();
      final keyboard = MediaQuery.viewInsetsOf(context).bottom;
      final bottomInset = keyboard > 0 ? keyboard : MediaQuery.paddingOf(context).bottom;
      final available = MediaQuery.sizeOf(context).height - topInset - PregoBottomSheet.contentTopInset - bottomInset;
      return PregoModalSurface(
        title: loc.mcpNativeRequestTitle,
        subtitle: null,
        onBack: null,
        onClose: () => context.pop(),
        width: PregoModalWidth.request,
        handleBottomSafeArea: true,
        topInset: topInset,
        child: SizedBox(
          height: math.max(0, math.min(620, available)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(PregoSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: MediaQuery.textScalerOf(context).scale(84),
                  child: Semantics(
                    liveRegion: true,
                    child: AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      layoutBuilder: (current, previous) =>
                          Stack(alignment: AlignmentDirectional.topStart, children: [...previous, ?current]),
                      child: Text(
                        _status(state: state, loc: loc),
                        key: ValueKey(_status(state: state, loc: loc)),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                if (state case FormReady(:final form, :final drafts, :final submission, :final connection)) ...[
                  Text(form.title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: PregoSpacing.md),
                  Text(form.message),
                  const SizedBox(height: PregoSpacing.lg),
                  for (final field in form.fields)
                    PendingFormFieldEditor(
                      key: ValueKey(field.id),
                      field: field,
                      draft: drafts[field.id],
                      issue: submission is FormSubmissionInvalid ? submission.fieldErrors[field.id] : null,
                      editable: connection == FormConnectionOwnership.active && submission is! FormSubmitting,
                      onChanged: (draft) => cubit.edit(fieldId: field.id, draft: draft),
                    ),
                  _Button(label: loc.questionModalSubmit, onPressed: cubit.canSubmit ? cubit.submit : null),
                  for (final choice in [FormDismissalChoice.decline, FormDismissalChoice.cancel])
                    _Button(
                      label: choice == FormDismissalChoice.decline ? loc.mcpExternalDecline : loc.mcpCancelRequest,
                      onPressed: connection == FormConnectionOwnership.active && submission is! FormSubmitting
                          ? () => cubit.decline(choice: choice)
                          : null,
                    ),
                ],
                if (state is FormReadFailed) ...[
                  _Button(label: loc.mcpRefresh, onPressed: cubit.refresh),
                  _Button(
                    label: loc.mcpCancelRequest,
                    onPressed: () {
                      context.pop();
                      onCancelUnavailable();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

String _status({required PendingFormState state, required AppLocalizations loc}) => switch (state) {
  FormLoading() => loc.mcpExternalLoading,
  FormDisconnected() || FormReady(connection: FormConnectionOwnership.retired) => loc.mcpExternalDisconnected,
  FormReadFailed() => loc.mcpReadFailed,
  FormReplySent() => loc.mcpFormReplySent,
  FormNoLongerPending() => loc.mcpExternalSettled,
  FormReady(submission: FormSubmitting()) => loc.mcpExternalSubmitting,
  FormReady(submission: FormSubmissionFailed()) => loc.mcpFormReplyFailed,
  FormReady(submission: FormSubmissionInvalid()) => loc.mcpFormInvalid,
  FormReady(submission: FormSubmissionRefused(reason: FormRefusalReason.unsupportedChoice)) =>
    loc.mcpActionNotSupported,
  FormReady(submission: FormSubmissionRefused()) => loc.mcpUnknownResponse,
  FormReady(:final form) =>
    form.fields.any(
          (field) => switch (field.schema) {
            FormSchemaUnknown() || FormTextSchema(format: FormTextFormat.unknown) => true,
            FormTextSchema() ||
            FormIntegerSchema() ||
            FormNumberSchema() ||
            FormBooleanSchema() ||
            FormChoiceSchema() ||
            FormChoicesSchema() => false,
          },
        )
        ? loc.mcpActionNotSupported
        : loc.mcpFormReady,
};

class const _Button({required final String label, required final VoidCallback? onPressed}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.md),
    child: PregoButtonsSolid(
      label: label,
      hierarchy: PregoButtonsSolidHierarchy.secondary,
      size: PregoButtonsSolidSize.md,
      fullWidth: true,
      onPressed: onPressed,
    ),
  );
}
