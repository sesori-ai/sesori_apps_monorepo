import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

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
  required final VoidCallback? onClose,
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
      ],
      child: _SessionActivityAnalyticsOwner(
        auditView: auditView,
        child: _MobileSessionDetailBody(
          auditView: auditView,
          onBack: onBack,
          onClose: onClose,
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

class const _MobileSessionDetailBody({
  required final String projectId,
  required final bool auditView,
  required final VoidCallback? onBack,
  required final VoidCallback? onClose,
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
      canShareImages: kIsWeb || defaultTargetPlatform != TargetPlatform.linux,
      openExternalLink: openExternalLink,
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
                  ),
          ),
      child: SessionDetailBody(
        onClose: onClose,
        projectId: projectId,
        sessionId: sessionId,
        sessionTitle: sessionTitle,
        readOnly: readOnly,
        banner: ConnectionBanner.maybeFor(context),
        onBack:
            onBack ??
            (showLeading
                ? () => isImperative
                      ? context.pop()
                      : context.goRoute(
                          AppRoute.sessions(
                            projectId: projectId,
                            projectName: projectName,
                          ),
                        )
                : null),
        onShowDiffs: auditView
            ? null
            : () => context.pushRoute(
                AppRoute.sessionDiffs(
                  projectId: projectId,
                  projectName: projectName,
                  sessionId: sessionId,
                ),
              ),
        bottomControlsBuilder: ({required context, required projectId, required sessionId, required state}) =>
            MobileSessionDetailComposerControls(
              projectId: projectId,
              sessionId: sessionId,
              state: state,
            ),
      ),
    );
  }
}

class const _SessionActivityAnalyticsOwner({
  required final bool auditView,
  required final Widget child,
}) extends StatefulWidget {
  @override
  State<_SessionActivityAnalyticsOwner> createState() => _SessionActivityAnalyticsOwnerState();
}

class _SessionActivityAnalyticsOwnerState() extends State<_SessionActivityAnalyticsOwner> {
  SessionActivityAnalyticsListener? _listener;
  StreamSubscription<AppRouteDef?>? _routeSubscription;
  bool? _wasRouteVisible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeSubscription ??= getIt<RouteSource>().currentRouteStream.listen((_) => _updateRouteVisibility());
    _updateRouteVisibility();
  }

  void _updateRouteVisibility() {
    // The root archive modal covers a live detail without changing the nested
    // pane route's isCurrent flag. Covered content must not mark new output seen.
    final topRoute = getIt<RouteSource>().currentRoute;
    final archiveIsOpen = topRoute == AppRouteDef.archivedSessions || topRoute == AppRouteDef.archivedSessionDetail;
    final isRouteVisible = (ModalRoute.of(context)?.isCurrent ?? false) && (widget.auditView || !archiveIsOpen);
    if (_wasRouteVisible != isRouteVisible) {
      context.read<SessionDetailCubit>().setRouteVisible(isVisible: isRouteVisible);
    }
    _wasRouteVisible = isRouteVisible;
    final listener = _listener;
    if (listener == null) {
      _listener = SessionActivityAnalyticsListener(
        sessionDetailCubit: context.read<SessionDetailCubit>(),
        lifecycleSource: getIt<LifecycleSource>(),
        productAnalyticsService: getIt<ProductAnalyticsService>(),
        initialRouteVisible: isRouteVisible,
      );
    } else {
      listener.setRouteVisible(isVisible: isRouteVisible);
    }
  }

  @override
  void dispose() {
    final listener = _listener;
    if (listener != null) unawaited(listener.dispose());
    unawaited(_routeSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
