import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/di/injection.dart";
import "widgets/session_detail_body.dart";

class SessionDetailScreen extends StatefulWidget {
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
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late final SessionDetailCubit _cubit;
  late final LifecycleSource _lifecycleSource;
  late final ProductAnalyticsService _productAnalyticsService;
  SessionActivityAnalyticsListener? _activityAnalyticsListener;

  @override
  void initState() {
    super.initState();
    _lifecycleSource = getIt<LifecycleSource>();
    _productAnalyticsService = getIt<ProductAnalyticsService>();
    _cubit = SessionDetailCubit(
      getIt<ConnectionService>(),
      loadService: getIt<SessionDetailLoadService>(),
      promptDispatcher: getIt<SessionRepository>(),
      permissionRepository: getIt<PermissionRepository>(),
      sessionViewingService: getIt<SessionViewingService>(),
      lifecycleSource: _lifecycleSource,
      composerDraftRepository: getIt<ComposerDraftRepository>(),
      productAnalyticsService: _productAnalyticsService,
      sessionId: widget.sessionId,
      projectId: widget.projectId,
      notificationCanceller: getIt<NotificationCanceller>(),
      failureReporter: getIt<FailureReporter>(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isRouteVisible = ModalRoute.of(context)?.isCurrent == true;
    final listener = _activityAnalyticsListener;
    if (listener == null) {
      _activityAnalyticsListener = SessionActivityAnalyticsListener(
        sessionDetailCubit: _cubit,
        lifecycleSource: _lifecycleSource,
        productAnalyticsService: _productAnalyticsService,
        initialRouteVisible: isRouteVisible,
      );
    } else {
      listener.setRouteVisible(isVisible: isRouteVisible);
    }
  }

  @override
  void dispose() {
    unawaited(_disposeOwnedState());
    super.dispose();
  }

  Future<void> _disposeOwnedState() async {
    await _activityAnalyticsListener?.dispose();
    await _cubit.close();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: SessionDetailBody(
        projectId: widget.projectId,
        projectName: widget.projectName,
        sessionId: widget.sessionId,
        sessionTitle: widget.sessionTitle,
        readOnly: widget.readOnly,
      ),
    );
  }
}
