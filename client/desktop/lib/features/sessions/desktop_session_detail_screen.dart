import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/external_link.dart";
import "../../core/widgets/desktop_composer_presentation_scope.dart";
import "../../core/widgets/desktop_page_toolbar.dart";

/// Desktop composition for the shared interactive transcript and composer.
class const DesktopSessionDetailScreen({
  super.key,
  required final String projectId,
  required final String sessionId,
  required final String? sessionTitle,
  required final bool readOnly,
  required final VoidCallback? onBack,
  required final VoidCallback onShowDiffs,
  required final SessionDetailSessionOpener onOpenSession,
  required final VoidCallback onOpenHarnessSettings,
  required final SessionListActionDispatcher sessionActions,

  /// Leaves the session once it is marked unread, so viewing it cannot mark
  /// it seen again.
  required final VoidCallback onMarkedUnread,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SessionDetailCubit>(
          create: (_) => createSessionDetailCubit(
            claimProjectView: true,
            locator: getIt,
            sessionId: sessionId,
            projectId: projectId,
          ),
        ),
        // The toolbar's session actions run through the same dispatcher as a
        // row's menu, on a throwaway list that holds only this session.
        BlocProvider<SessionListCubit>(
          create: (_) => createSessionListCubit(
            locator: getIt,
            projectId: projectId,
            mode: const SessionListMode.actions(sessions: []),
          ),
        ),
      ],
      child: DesktopComposerPresentationScope(
        child: SessionDetailActivityOwner(
          routeSource: getIt<RouteSource>(),
          lifecycleSource: getIt<LifecycleSource>(),
          productAnalyticsService: getIt<ProductAnalyticsService>(),
          expectedDetailRoute: AppRouteDef.sessionDetail,
          child: DesktopSessionDetailView(
            projectId: projectId,
            sessionId: sessionId,
            sessionTitle: sessionTitle,
            readOnly: readOnly,
            onBack: onBack,
            onShowDiffs: onShowDiffs,
            onOpenSession: onOpenSession,
            onOpenHarnessSettings: onOpenHarnessSettings,
            sessionActions: sessionActions,
            onMarkedUnread: onMarkedUnread,
            messageImageRepository: getIt.get<MessageImageRepository>,
            imageSaver: getIt.get<ImageSaver>,
            imageClipboard: getIt.get<ImageClipboard>,
            imageSharer: getIt.get<ImageSharer>,
            canShareImages: defaultTargetPlatform != TargetPlatform.linux,
          ),
        ),
      ),
    );
  }
}

class const DesktopSessionDetailView({
  super.key,
  required final String projectId,
  required final String sessionId,
  required final String? sessionTitle,
  required final bool readOnly,
  required final VoidCallback? onBack,
  required final VoidCallback onShowDiffs,
  required final SessionDetailSessionOpener onOpenSession,
  required final VoidCallback onOpenHarnessSettings,
  required final SessionListActionDispatcher sessionActions,

  /// Leaves the session once it is marked unread, so viewing it cannot mark
  /// it seen again.
  required final VoidCallback onMarkedUnread,
  required final SessionDetailCapabilityProvider<MessageImageRepository> messageImageRepository,
  required final SessionDetailCapabilityProvider<ImageSaver> imageSaver,
  required final SessionDetailCapabilityProvider<ImageClipboard> imageClipboard,
  required final SessionDetailCapabilityProvider<ImageSharer> imageSharer,
  required final bool canShareImages,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SessionDetailPresentationScope(
      messageImageRepository: messageImageRepository,
      imageSaver: imageSaver,
      imageClipboard: imageClipboard,
      imageSharer: imageSharer,
      canShareImages: canShareImages,
      openExternalLink: openDesktopExternalLink,
      openSession: onOpenSession,
      openHarnessSettings: onOpenHarnessSettings,
      child: _MarkUnreadShortcut(
        onMarkUnread: () {
          final session = context.read<SessionDetailCubit>().state.hydratedSession;
          if (session != null) _markUnread(context: context, session: session);
        },
        child: SessionDetailBody(
          onClose: null,
          projectId: projectId,
          sessionId: sessionId,
          sessionTitle: sessionTitle,
          readOnly: readOnly,
          banner: null,
          onBack: onBack,
          onShowDiffs: onShowDiffs,
          bottomControlsBuilder: ({required context, required projectId, required sessionId, required state}) =>
              SessionDetailComposerControls(
                projectId: projectId,
                sessionId: sessionId,
                state: state,
              ),
          pageChrome: SessionDetailPageChrome(
            maxContentWidth: maxContentWidth,
            headerBuilder: _buildToolbar,
          ),
        ),
      ),
    );
  }

  static const double maxContentWidth = 760;

  void _markUnread({required BuildContext context, required Session session}) {
    sessionActions.handleSessionMarkUnread(
      context: context,
      cubit: context.read<SessionListCubit>(),
      session: session,
    );
    onMarkedUnread();
  }

  Widget _buildToolbar({
    required BuildContext context,
    required String title,
    required String? subtitle,
    required bool isBusy,
    required VoidCallback? onShowDiffs,
    required Session? session,
  }) {
    final loc = context.loc;
    final onBack = this.onBack;
    return DesktopPageToolbar(
      leading: onBack == null
          ? null
          : IconButton(
              key: const Key("desktop-session-page-back"),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack,
              icon: const Icon(TablerRegular.arrow_left, size: 18),
            ),
      title: title,
      subtitle: subtitle == null ? null : PregoNavSubtitle(text: subtitle),
      actions: [
        if (isBusy) const SizedBox.square(dimension: 18, child: PregoActivityIndicator(color: null)),
        IconButton(
          key: const Key("desktop-session-page-mark-unread"),
          tooltip: loc.sessionListMarkUnread,
          onPressed: session == null ? null : () => _markUnread(context: context, session: session),
          icon: const Icon(TablerRegular.mail, size: 18),
        ),
        if (onShowDiffs != null)
          PregoButtonsSolid(
            key: const Key("desktop-session-page-changes"),
            label: loc.desktopSessionPageChanges,
            leadingIcon: TablerRegular.git_compare,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.sm,
            onPressed: onShowDiffs,
          ),
        PregoAnchorMenu(
          flat: true,
          menuWidth: 220,
          acquireOpenLease: () => context.read<SessionListCubit>().retainActionScope(),
          entriesBuilder: () => session == null
              ? const []
              : sessionActions.sessionMenuEntries(
                  context: context,
                  cubit: context.read<SessionListCubit>()..updateActionSession(session: session),
                  session: session,
                  includeReadToggle: false,
                ),
          triggerBuilder: (context, openMenu) => IconButton(
            key: const Key("desktop-session-page-more"),
            tooltip: loc.sessionDetailMoreActions,
            onPressed: session == null ? null : openMenu,
            icon: const Icon(TablerRegular.dots, size: 18),
          ),
        ),
      ],
    );
  }
}

/// `Shift+Cmd/Ctrl+U` marks the open session unread. It lives with the page, so
/// it is inert wherever no session is open.
class const _MarkUnreadShortcut({required final VoidCallback onMarkUnread, required final Widget child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      SingleActivator(
        LogicalKeyboardKey.keyU,
        shift: true,
        meta: defaultTargetPlatform == TargetPlatform.macOS,
        control: defaultTargetPlatform != TargetPlatform.macOS,
        includeRepeats: false,
      ): onMarkUnread,
    },
    child: child,
  );
}
