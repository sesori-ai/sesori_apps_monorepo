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
import "pending_request_auto_dismiss.dart";

typedef SessionExternalActionCubitFactory = SessionExternalActionCubit Function({
  required String requestId,
  required String sessionId,
});

/// A request-scoped layer; dismissal never sends a native response.
Future<void> showExternalActionModal({
  required BuildContext context,
  required String requestId,
  required String sessionId,
  required SessionExternalActionCubitFactory createCubit,
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
        child: ExternalActionModal(topInset: topInset, onSettled: onSettled, onCancelUnavailable: onCancelUnavailable),
      ),
    ),
  );
}

class const ExternalActionModal({
  required final double topInset,
  required final VoidCallback onSettled,
  required final VoidCallback onCancelUnavailable,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => BlocConsumer<SessionExternalActionCubit, SessionExternalActionState>(
    listener: (_, state) {
      if (state is ExternalActionSettled) onSettled();
    },
    builder: (context, state) {
      final loc = context.loc;
      final available =
          MediaQuery.sizeOf(context).height -
          topInset -
          PregoBottomSheet.contentTopInset -
          MediaQuery.paddingOf(context).bottom;
      return PregoModalSurface(
        title: loc.mcpNativeRequestTitle,
        subtitle: null,
        onBack: null,
        onClose: () => context.pop(),
        width: PregoModalWidth.request,
        handleBottomSafeArea: true,
        topInset: topInset,
        child: SizedBox(
          height: math.max(0, math.min(520, available)),
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
                      duration: context.isReducedMotion ? Duration.zero : const Duration(milliseconds: 180),
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
                if (state case ExternalActionReady(
                  :final action,
                  :final destination,
                  :final submission,
                  :final browser,
                )) ...[
                  Text(action.title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: PregoSpacing.md),
                  Text(action.message),
                  const SizedBox(height: PregoSpacing.lg),
                  if (destination != null) ...[
                    Text(destination.origin),
                    const SizedBox(height: PregoSpacing.md),
                    _Button(
                      label: loc.mcpOpenBrowser,
                      onPressed: browser is ExternalActionBrowserOpening || submission is ExternalActionSubmitting
                          ? null
                          : context.read<SessionExternalActionCubit>().openBrowser,
                    ),
                  ],
                  Text(loc.mcpExternalReplyExplanation),
                  const SizedBox(height: PregoSpacing.lg),
                  for (final choice in ExternalActionChoice.values)
                    if (choice != ExternalActionChoice.unknown && action.choices.contains(choice))
                      _Button(
                        label: switch (choice) {
                          ExternalActionChoice.accept =>
                            action.purpose == ExternalActionPurpose.connectorConsent
                                ? loc.mcpExternalAcceptConsent
                                : loc.mcpExternalContinue,
                          ExternalActionChoice.decline => loc.mcpExternalDecline,
                          ExternalActionChoice.cancel => loc.mcpCancelRequest,
                          ExternalActionChoice.unknown => throw StateError("Unknown choice is not displayed"),
                        },
                        onPressed:
                            submission is ExternalActionSubmitting ||
                                (choice == ExternalActionChoice.accept && destination == null)
                            ? null
                            : () => context.read<SessionExternalActionCubit>().reply(choice: choice),
                      ),
                ],
                if (state is ExternalActionReadFailed) ...[
                  _Button(label: loc.mcpRefresh, onPressed: context.read<SessionExternalActionCubit>().refresh),
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

String _status({required SessionExternalActionState state, required AppLocalizations loc}) => switch (state) {
  ExternalActionLoading() => loc.mcpExternalLoading,
  ExternalActionDisconnected() => loc.mcpExternalDisconnected,
  ExternalActionReadFailed() => loc.mcpReadFailed,
  ExternalActionReplySent() => loc.mcpExternalReplySent,
  ExternalActionNoLongerPending() => loc.mcpExternalSettled,
  ExternalActionReady(submission: ExternalActionSubmitting()) => loc.mcpExternalSubmitting,
  ExternalActionReady(submission: ExternalActionSubmissionFailed()) => loc.mcpExternalReplyFailed,
  ExternalActionReady(submission: ExternalActionSubmissionRefused(result: ExternalActionUnsupportedChoice())) =>
    loc.mcpActionNotSupported,
  ExternalActionReady(submission: ExternalActionSubmissionRefused()) => loc.mcpUnknownResponse,
  ExternalActionReady(destination: null) => loc.mcpExternalDestinationUnavailable,
  ExternalActionReady(browser: ExternalActionBrowserOpening()) => loc.mcpExternalBrowserOpening,
  ExternalActionReady(browser: ExternalActionBrowserFailed()) => loc.mcpExternalBrowserFailed,
  ExternalActionReady(browser: ExternalActionBrowserOpened()) => loc.mcpExternalBrowserOpened,
  ExternalActionReady() => loc.mcpExternalReady,
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
