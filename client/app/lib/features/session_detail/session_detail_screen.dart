import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/di/injection.dart";
import "../../core/external_link.dart";
import "../../core/routing/app_router.dart";
import "../../core/routing/imperative_pane_route.dart";
import "widgets/session_detail_composer_controls.dart";

class const SessionDetailScreen({
  super.key,
  required final String projectId,
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
          create: (_) => SessionDetailCubit(
            getIt<ConnectionService>(),
            loadService: getIt<SessionDetailLoadService>(),
            promptDispatcher: getIt<SessionRepository>(),
            permissionRepository: getIt<PermissionRepository>(),
            sessionViewingService: getIt<SessionViewingService>(),
            projectViewingService: getIt<ProjectViewingService>(),
            lifecycleSource: getIt<LifecycleSource>(),
            composerDraftRepository: getIt<ComposerDraftRepository>(),
            productAnalyticsService: getIt<ProductAnalyticsService>(),
            sessionId: sessionId,
            projectId: projectId,
            notificationCanceller: getIt<NotificationCanceller>(),
            failureReporter: getIt<FailureReporter>(),
          ),
        ),
      ],
      child: _SessionActivityAnalyticsOwner(
        child: _MobileSessionDetailBody(
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
      openSession:
          ({
            required projectId,
            required sessionId,
            required sessionTitle,
            required readOnly,
          }) => context.pushRoute(
            AppRoute.sessionDetail(
              projectId: projectId,
              projectName: projectName,
              sessionId: sessionId,
              readOnly: readOnly,
              sessionTitle: sessionTitle,
            ),
          ),
      child: SessionDetailBody(
        projectId: projectId,
        sessionId: sessionId,
        sessionTitle: sessionTitle,
        readOnly: readOnly,
        banner: ConnectionBanner.maybeFor(context),
        onBack: showLeading
            ? () => isImperative
                  ? context.pop()
                  : context.goRoute(
                      AppRoute.sessions(
                        projectId: projectId,
                        projectName: projectName,
                      ),
                    )
            : null,
        onShowDiffs: () => context.pushRoute(
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

class const _SessionActivityAnalyticsOwner({required final Widget child}) extends StatefulWidget {
  @override
  State<_SessionActivityAnalyticsOwner> createState() => _SessionActivityAnalyticsOwnerState();
}

class _SessionActivityAnalyticsOwnerState() extends State<_SessionActivityAnalyticsOwner> {
  SessionActivityAnalyticsListener? _listener;
  bool? _wasRouteVisible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isRouteVisible = ModalRoute.of(context)?.isCurrent ?? false;
    if (isRouteVisible && _wasRouteVisible == false) {
      context.read<SessionDetailCubit>().reassertViewingSession();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
