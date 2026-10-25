import "package:flutter/foundation.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart" show McpInventoryRequest, McpSessionScope, Session;
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/external_link.dart";
import "../../core/routing/app_router.dart";
import "../../core/routing/imperative_pane_route.dart";
import "widgets/session_detail_composer_controls.dart";

class const SessionDetailScreen({
  super.key,
  required final String projectId,
  required final bool auditView,
  required final VoidCallback? onBack,
  required final String? projectName,
  required final String sessionId,
  final String? sessionTitle,
  final bool readOnly = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => createSessionDetailCubit(
            claimProjectView: !auditView,
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
        // Lazy: only the live page's menu actions run on it.
        BlocProvider(
          create: (_) => createSessionListCubit(
            locator: getIt,
            projectId: projectId,
            mode: const SessionListMode.actions(sessions: []),
          ),
        ),
      ],
      child: SessionDetailActivityOwner(
        routeSource: getIt<RouteSource>(),
        lifecycleSource: getIt<LifecycleSource>(),
        productAnalyticsService: getIt<ProductAnalyticsService>(),
        expectedDetailRoute: auditView ? AppRouteDef.archivedSessionDetail : AppRouteDef.sessionDetail,
        child: _MobileSessionDetailBody(
          auditView: auditView,
          onBack: onBack,
          projectId: projectId,
          projectName: projectName,
          sessionId: sessionId,
          sessionTitle: sessionTitle,
          readOnly: readOnly,
        ),
      ),
    );
  }
}

/// The open page's actions. Each one that takes the session away from the
/// reader — archive, delete, Mark as unread — returns to the session list.
const _sessionActions = SessionListActionDispatcher(
  deleteConfirmation: SessionDeleteConfirmation.sheet,
  onSessionArchived: closeDeletedSessionRoute,
  onSessionDeleted: closeDeletedSessionRoute,
  onSessionMarkedUnread: _leaveMarkedUnreadSession,
);

void _leaveMarkedUnreadSession({required BuildContext context, required Session session}) =>
    closeDeletedSessionRoute(context: context, sessionId: session.id);

class const _MobileSessionDetailBody({
  required final String projectId,
  required final bool auditView,
  required final VoidCallback? onBack,
  required final String? projectName,
  required final String sessionId,
  required final String? sessionTitle,
  required final bool readOnly,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isSplit = SessionSplitScope.maybeOf(context)?.isSplit ?? false;
    final isImperative = isImperativePaneRoute(context);
    final showLeading = !isSplit || isImperative;
    return SessionDetailPresentationScope(
      messageImageRepository: getIt.get<MessageImageRepository>,
      imageSaver: getIt.get<ImageSaver>,
      imageClipboard: getIt.get<ImageClipboard>,
      imageSharer: getIt.get<ImageSharer>,
      sessionRepository: getIt.get<SessionRepository>,
      createPendingFormCubit: ({required requestId, required sessionId}) => PendingFormCubit(
        service: getIt<PendingFormService>(),
        connectionService: getIt<ConnectionService>(),
        requestId: requestId,
        sessionId: sessionId,
      ),
      createExternalActionCubit: ({required requestId, required sessionId}) => SessionExternalActionCubit(
        service: getIt<SessionExternalActionService>(),
        connectionService: getIt<ConnectionService>(),
        urlLauncher: getIt<UrlLauncher>(),
        requestId: requestId,
        sessionId: sessionId,
      ),
      canShareImages: kIsWeb || defaultTargetPlatform != TargetPlatform.linux,
      openExternalLink: openExternalLink,
      openBridgeSettings: () => context.pushRoute(const AppRoute.settings()),
      openHarnessSettings: () => context.pushRoute(
        const AppRoute.settingsHarnesses(presentation: HarnessSettingsPresentation.modal),
      ),
      openSession:
          ({
            required projectId,
            required sessionId,
            required sessionTitle,
            required readOnly,
          }) => context.pushRoute(
            auditView
                ? AppRoute.archivedSessionDetail(
                    projectId: projectId,
                    projectName: projectName,
                    sessionId: sessionId,
                    sessionTitle: sessionTitle,
                  )
                : AppRoute.sessionDetail(
                    projectId: projectId,
                    projectName: projectName,
                    sessionId: sessionId,
                    readOnly: readOnly,
                    sessionTitle: sessionTitle,
                    fromLaunch: false,
                  ),
          ),
      child: SessionDetailBody(
        projectId: projectId,
        sessionId: sessionId,
        sessionTitle: sessionTitle,
        readOnly: readOnly,
        banner: ConnectionBanner.maybeFor(context),
        onBack:
            onBack ??
            (showLeading ? () => isImperative ? context.pop() : context.goRoute(const AppRoute.home()) : null),
        onShowDiffs: auditView
            ? null
            : () => context.pushRoute(
                AppRoute.sessionDiffs(
                  projectId: projectId,
                  projectName: projectName,
                  sessionId: sessionId,
                ),
              ),
        pageChrome: null,
        // Audit views retain read-only inventory without session mutations.
        menuEntriesBuilder: ({required context, required session}) => [
          PregoMenuItem(
            leadingIcon: TablerRegular.plug,
            title: context.loc.mcpMenuLabel,
            subtitle: null,
            isSelected: false,
            shortcutLabel: null,
            onTap: () async {
              final state = context.read<SessionDetailCubit>().state;
              await showMcpInventory(
                context: context,
                request: McpInventoryRequest(
                  pluginId: session.pluginId,
                  scope: McpSessionScope(sessionId: session.id),
                ),
                createService: getIt.call<McpService>,
                authenticationService: getIt.call<McpAuthenticationService>,
                mutationsAllowed:
                    !readOnly &&
                    !auditView &&
                    session.parentID == null &&
                    session.time?.archived == null &&
                    !(state is SessionDetailLoaded && state.isArchived),
              );
            },
          ),
          if (!auditView && session.parentID == null)
            ..._sessionActions.sessionMenuEntries(
              context: context,
              cubit: context.read<SessionListCubit>()..updateActionSession(session: session),
              session: session,
              readEntry: SessionReadMenuEntry.markUnread,
            ),
        ],
        bottomControlsBuilder: ({required context, required projectId, required sessionId, required source}) =>
            MobileSessionDetailComposerControls(
              projectId: projectId,
              sessionId: sessionId,
              source: source,
            ),
      ),
    );
  }
}
