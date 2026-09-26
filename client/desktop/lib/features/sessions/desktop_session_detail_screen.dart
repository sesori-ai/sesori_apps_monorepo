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
import "../../core/widgets/desktop_command_palette.dart";
import "../../core/widgets/desktop_composer_presentation_scope.dart";
import "../../core/widgets/desktop_page_toolbar.dart";
import "../../core/widgets/desktop_session_signals.dart";

/// Desktop composition for the shared interactive transcript and composer.
class const DesktopSessionDetailScreen({
  super.key,
  required final String projectId,
  required final String sessionId,
  required final String? sessionTitle,
  required final bool readOnly,
  required final String? projectName,

  /// Opens the project's session list from the toolbar breadcrumb.
  required final VoidCallback onOpenProject,

  /// Returns a subtask to the session that started it, from the toolbar breadcrumb.
  required final void Function({required String parentSessionId}) onOpenParentSession,
  required final VoidCallback onShowDiffs,
  required final SessionDetailSessionOpener onOpenSession,
  required final VoidCallback onOpenHarnessSettings,
  required final VoidCallback onOpenBridgeSettings,
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
        // Lazy, so only a page whose Changes button shows asks for totals.
        BlocProvider<DiffSummaryCubit>(
          create: (_) => DiffSummaryCubit(
            sessionRepository: getIt<SessionRepository>(),
            connectionService: getIt<ConnectionService>(),
            sessionId: sessionId,
            refreshInterval: const Duration(seconds: 2),
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
            projectName: projectName,
            onOpenProject: onOpenProject,
            onOpenParentSession: onOpenParentSession,
            onShowDiffs: onShowDiffs,
            onOpenSession: onOpenSession,
            onOpenHarnessSettings: onOpenHarnessSettings,
            onOpenBridgeSettings: onOpenBridgeSettings,
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
  required final String? projectName,

  /// Opens the project's session list from the toolbar breadcrumb.
  required final VoidCallback onOpenProject,

  /// Returns a subtask to the session that started it, from the toolbar breadcrumb.
  required final void Function({required String parentSessionId}) onOpenParentSession,
  required final VoidCallback onShowDiffs,
  required final SessionDetailSessionOpener onOpenSession,
  required final VoidCallback onOpenHarnessSettings,
  required final VoidCallback onOpenBridgeSettings,
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
      openBridgeSettings: onOpenBridgeSettings,
      child: _MarkUnreadShortcut(
        onMarkUnread: () {
          final session = context.read<SessionDetailCubit>().state.hydratedSession;
          if (session != null) _markUnread(context: context, session: session);
        },
        child: SessionDetailBody(
          projectId: projectId,
          sessionId: sessionId,
          sessionTitle: sessionTitle,
          readOnly: readOnly,
          banner: null,
          // The page goes back with Cmd/Ctrl+[, so its toolbar has no Back.
          onBack: null,
          onShowDiffs: onShowDiffs,
          bottomControlsBuilder: ({required context, required projectId, required sessionId, required state}) =>
              SessionDetailComposerControls(
                projectId: projectId,
                sessionId: sessionId,
                state: state,
              ),
          pageChrome: SessionDetailPageChrome(
            columnWidths: const SessionDetailColumnWidths(
              transcript: maxTranscriptWidth,
              composer: maxComposerWidth,
            ),
            headerBuilder: _buildToolbar,
            foldActivator: _foldShortcut,
            unfoldActivator: _unfoldShortcut,
          ),
          menuEntriesBuilder: null,
        ),
      ),
    );
  }

  /// Caps the transcript's reading column, which is deliberately wider than
  /// the composer's: long assistant prose reads better in a longer measure.
  ///
  /// Bounded above by the timestamp peek. A drag slides the row content 108 px
  /// left and brings a 108 px gutter in from the right, so the whole reveal
  /// stays inside the window only while the column is at most
  /// `paneWidth - 216`. On the 1240 px window the desktop is designed around
  /// that ceiling is 1024, leaving 960 with 64 px of headroom. Widening past
  /// the ceiling is not guarded and does not break: the peek degrades to the
  /// phone's behaviour, where content slides under the window edge during the
  /// drag, and a settled reveal is never clipped at any width.
  static const double maxTranscriptWidth = 960;

  /// Caps the composer, its pointer-picker pills and the needs-you cards above
  /// them. A text field and a pill row read as stretched long before body text
  /// does, so they stay at the narrower measure.
  static const double maxComposerWidth = 760;

  static SingleActivator get _foldShortcut => desktopShortcut(key: LogicalKeyboardKey.minus);
  static SingleActivator get _unfoldShortcut => desktopShortcut(key: LogicalKeyboardKey.equal);

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
    required bool isBusy,
    required VoidCallback? onShowDiffs,
    required Session? session,
  }) {
    final loc = context.loc;
    final state = context.read<SessionDetailCubit>().state;
    final isAwaitingInput = switch (state) {
      SessionDetailLoaded(:final pendingQuestions, :final pendingPermissions) =>
        pendingQuestions.isNotEmpty || pendingPermissions.isNotEmpty,
      SessionDetailLoading() || SessionDetailHarnessUnavailable() || SessionDetailFailed() => false,
    };
    return DesktopPageToolbar(
      breadcrumb: switch (session?.parentID) {
        final parentSessionId? => (
          label: loc.desktopSessionParentBreadcrumb,
          onPressed: () => onOpenParentSession(parentSessionId: parentSessionId),
        ),
        null => (label: projectName ?? loc.sessionListTitle, onPressed: onOpenProject),
      },
      // The turning sparkle leads the title while the session works; a waiting question takes its place.
      status: isAwaitingInput || isBusy
          ? DesktopSessionSignals(isAwaitingInput: isAwaitingInput, isRunning: !isAwaitingInput, isUnseen: false)
          : null,
      title: title,
      subtitle: null,
      actions: [
        if (onShowDiffs != null)
          BlocBuilder<DiffSummaryCubit, DiffSummaryState>(
            builder: (context, summary) => PregoButtonsSolid(
              key: const Key("desktop-session-page-changes"),
              label: loc.sessionChangesLabel,
              leadingIcon: TablerRegular.git_compare,
              labelTrailing: sessionChangesCounts(state: summary, style: context.prego.textTheme.textSm.medium),
              hierarchy: PregoButtonsSolidHierarchy.secondary,
              size: PregoButtonsSolidSize.sm,
              onPressed: onShowDiffs,
            ),
          ),
        if (state case SessionDetailLoaded(:final transcriptFolded))
          IconButton(
            key: const Key("desktop-session-page-fold"),
            tooltip: transcriptFolded
                ? loc.desktopShortcutHint(loc.transcriptUnfoldAll, desktopShortcutLabel(shortcut: _unfoldShortcut))
                : loc.desktopShortcutHint(loc.transcriptFoldAll, desktopShortcutLabel(shortcut: _foldShortcut)),
            onPressed: () => context.read<SessionDetailCubit>().setTranscriptFolded(folded: !transcriptFolded),
            icon: Icon(
              transcriptFolded ? TablerRegular.separator_horizontal : TablerRegular.fold,
              size: PregoIconSize.md,
            ),
          ),
        PregoAnchorMenu(
          flat: true,
          menuWidth: 220,
          acquireOpenLease: () => context.read<SessionListCubit>().retainActionScope(),
          entriesBuilder: () => session == null
              ? const []
              : [
                  if (!readOnly &&
                      session.time?.archived == null &&
                      !(state is SessionDetailLoaded && state.isArchived))
                    sessionAutoContinuationMenuEntry(context: context, session: session),
                  PregoMenuItem(
                    leadingIcon: TablerRegular.mail,
                    title: loc.sessionListMarkUnread,
                    subtitle: null,
                    isSelected: false,
                    shortcutLabel: defaultTargetPlatform == TargetPlatform.macOS ? "⇧⌘U" : "Ctrl+Shift+U",
                    onTap: () => _markUnread(context: context, session: session),
                  ),
                  ...sessionActions.sessionMenuEntries(
                    context: context,
                    cubit: context.read<SessionListCubit>()..updateActionSession(session: session),
                    session: session,
                    readEntry: SessionReadMenuEntry.none,
                  ),
                ],
          triggerBuilder: (context, openMenu) => IconButton(
            key: const Key("desktop-session-page-more"),
            tooltip: loc.sessionDetailMoreActions,
            onPressed: session == null ? null : openMenu,
            icon: const Icon(TablerRegular.dots, size: PregoIconSize.md),
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
