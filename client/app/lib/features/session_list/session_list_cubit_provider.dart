import "package:flutter/widgets.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/di/injection.dart";

class const SessionListCubitProvider({
  super.key,
  required final String projectId,
  required final bool? initialSupportsDedicatedWorktrees,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SessionListCubit(
        sessionService: getIt<SessionService>(),
        sessionListService: getIt<SessionListService>(),
        projectRepository: getIt<ProjectRepository>(),
        connectionService: getIt<ConnectionService>(),
        sseEventTracker: getIt<SseEventTracker>(),
        sessionUnseenTracker: getIt<SessionUnseenTracker>(),
        projectViewingService: getIt<ProjectViewingService>(),
        routeSource: getIt<RouteSource>(),
        projectId: projectId,
        initialSupportsDedicatedWorktrees: initialSupportsDedicatedWorktrees,
        failureReporter: getIt<FailureReporter>(),
      ),
      child: child,
    );
  }
}
