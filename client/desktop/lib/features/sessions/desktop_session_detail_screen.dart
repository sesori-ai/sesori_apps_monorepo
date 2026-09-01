import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/di/injection.dart";
import "../../core/external_link.dart";

/// Desktop composition for the shared interactive transcript.
///
/// Message composition remains product-owned and arrives in the next desktop
/// slice. Transcript actions, child-session navigation, permissions, questions,
/// and image actions remain available here.
class const DesktopSessionDetailScreen({
  super.key,
  required final String projectId,
  required final String sessionId,
  required final String? sessionTitle,
  required final bool readOnly,
  required final VoidCallback onBack,
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
      child: _SessionActivityAnalyticsOwner(
        child: DesktopSessionDetailView(
          projectId: projectId,
          sessionId: sessionId,
          sessionTitle: sessionTitle,
          readOnly: readOnly,
          onBack: onBack,
          onOpenSession: onOpenSession,
          messageImageRepository: getIt<MessageImageRepository>(),
          imageSaver: getIt<ImageSaver>(),
          imageClipboard: getIt<ImageClipboard>(),
          imageSharer: getIt<ImageSharer>(),
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
  required final SessionDetailSessionOpener onOpenSession,
  required final MessageImageRepository messageImageRepository,
  required final ImageSaver imageSaver,
  required final ImageClipboard imageClipboard,
  required final ImageSharer imageSharer,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SessionDetailPresentationScope(
      messageImageRepository: () => messageImageRepository,
      imageSaver: () => imageSaver,
      imageClipboard: () => imageClipboard,
      imageSharer: () => imageSharer,
      openExternalLink: openDesktopExternalLink,
      openSession: onOpenSession,
      child: SessionDetailBody(
        projectId: projectId,
        sessionId: sessionId,
        sessionTitle: sessionTitle,
        readOnly: readOnly,
        banner: null,
        onBack: onBack,
        onShowDiffs: null,
        // Desktop exposes the complete interactive transcript first; the
        // product-owned composer is added by the next plan slice.
        bottomControlsBuilder: null,
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isRouteVisible = ModalRoute.of(context)?.isCurrent ?? false;
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
