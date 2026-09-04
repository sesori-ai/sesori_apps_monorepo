import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

/// Presents accepted backend `tui.toast.show` events on a product shell's
/// root navigator overlay.
///
/// The cubit remains responsible for filtering and typing SSE events; this
/// shared Flutter boundary owns their Prego presentation.
class const SseToastListener({
  required final GlobalKey<NavigatorState> navigatorKey,
  required final Widget child,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocListener<SseToastCubit, SseToastState>(
      listener: (context, state) {
        if (state case SseToastShow(:final title, :final message, :final variant)) {
          final OverlayState? overlay = navigatorKey.currentState?.overlay;
          if (overlay == null) {
            logw("Cannot present an SSE toast before the navigator overlay is ready");
            return;
          }
          PregoPopupAlertPresenter.fromOverlayState(overlay).show(
            title: title ?? message,
            content: title == null ? const PregoPopupAlertContent() : PregoPopupAlertContent(message: message),
            variant: switch (variant) {
              SseToastVariant.info => PregoPopupAlertsNotificationsVariant.info,
              SseToastVariant.success => PregoPopupAlertsNotificationsVariant.success,
              SseToastVariant.warning => PregoPopupAlertsNotificationsVariant.warning,
              SseToastVariant.error => PregoPopupAlertsNotificationsVariant.error,
            },
            duration: switch (variant) {
              SseToastVariant.error || SseToastVariant.warning => const Duration(seconds: 8),
              SseToastVariant.info || SseToastVariant.success => const Duration(seconds: 4),
            },
          );
        }
      },
      child: child,
    );
  }
}
