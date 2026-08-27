import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/di/injection.dart";
import "widgets/session_detail_body.dart";

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
        if (!readOnly)
          BlocProvider(
            create: (_) => VoiceInputCubit(service: getIt<VoiceTranscriptionService>()),
          ),
      ],
      child: _SessionActivityAnalyticsOwner(
        child: SessionDetailBody(
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
