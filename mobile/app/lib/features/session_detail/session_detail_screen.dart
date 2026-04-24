import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/di/injection.dart";
import "widgets/session_detail_body.dart";

class SessionDetailScreen extends StatelessWidget {
  final String? projectId;
  final String sessionId;
  final String? sessionTitle;
  final bool readOnly;

  const SessionDetailScreen({
    super.key,
    required this.projectId,
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
        variantOptionsBuilder: getIt<AgentVariantOptionsBuilder>(),
        sessionId: sessionId,
        projectId: projectId,
        notificationCanceller: getIt<NotificationCanceller>(),
        failureReporter: getIt<FailureReporter>(),
      ),
      child: SessionDetailBody(
        projectId: projectId,
        sessionId: sessionId,
        sessionTitle: sessionTitle,
        readOnly: readOnly,
      ),
    );
  }
}
