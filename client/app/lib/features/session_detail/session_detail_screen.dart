import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/di/injection.dart";
import "widgets/session_detail_body.dart";

class SessionDetailScreen extends StatelessWidget {
  final String projectId;
  final String? projectName;
  final String sessionId;
  final String? sessionTitle;
  final bool readOnly;

  const SessionDetailScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.sessionId,
    this.sessionTitle,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SessionDetailCubit(
        getIt<ConnectionService>(),
        loadService: getIt<SessionDetailLoadService>(),
        promptDispatcher: getIt<SessionRepository>(),
        permissionRepository: getIt<PermissionRepository>(),
        sessionViewingService: getIt<SessionViewingService>(),
        lifecycleSource: getIt<LifecycleSource>(),
        productAnalyticsService: getIt<ProductAnalyticsService>(),
        sessionId: sessionId,
        projectId: projectId,
        notificationCanceller: getIt<NotificationCanceller>(),
        failureReporter: getIt<FailureReporter>(),
      ),
      child: _SessionActivityAnalyticsScope(
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

class _SessionActivityAnalyticsScope extends StatefulWidget {
  final Widget child;

  const _SessionActivityAnalyticsScope({required this.child});

  @override
  State<_SessionActivityAnalyticsScope> createState() => _SessionActivityAnalyticsScopeState();
}

class _SessionActivityAnalyticsScopeState extends State<_SessionActivityAnalyticsScope> {
  SessionActivityAnalyticsConsumer? _consumer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeVisible = ModalRoute.of(context)?.isCurrent == true;
    final consumer = _consumer;
    if (consumer == null) {
      _consumer = SessionActivityAnalyticsConsumer(
        sessionDetailCubit: context.read<SessionDetailCubit>(),
        routeSource: getIt<RouteSource>(),
        lifecycleSource: getIt<LifecycleSource>(),
        productAnalyticsService: getIt<ProductAnalyticsService>(),
        routeVisible: routeVisible,
      );
    } else {
      consumer.setRouteVisible(isVisible: routeVisible);
    }
  }

  @override
  void dispose() {
    final consumer = _consumer;
    if (consumer != null) unawaited(consumer.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
