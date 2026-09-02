import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/di/injection.dart";
import "../../core/external_link.dart";
import "../../core/widgets/desktop_composer_presentation_scope.dart";

/// Desktop composition for the shared interactive transcript and composer.
class const DesktopSessionDetailScreen({
  super.key,
  required final String projectId,
  required final String sessionId,
  required final String? sessionTitle,
  required final bool readOnly,
  required final VoidCallback onBack,
  required final VoidCallback onShowDiffs,
  required final SessionDetailSessionOpener onOpenSession,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
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
      child: DesktopComposerPresentationScope(
        child: _SessionActivityAnalyticsOwner(
          child: DesktopSessionDetailView(
            projectId: projectId,
            sessionId: sessionId,
            sessionTitle: sessionTitle,
            readOnly: readOnly,
            onBack: onBack,
            onShowDiffs: onShowDiffs,
            onOpenSession: onOpenSession,
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
  required final VoidCallback onBack,
  required final VoidCallback onShowDiffs,
  required final SessionDetailSessionOpener onOpenSession,
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
      child: SessionDetailBody(
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
