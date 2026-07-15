import "package:flutter/widgets.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/di/injection.dart";

class SessionListCubitProvider extends StatelessWidget {
  final String projectId;
  final Widget child;

  const SessionListCubitProvider({
    super.key,
    required this.projectId,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SessionListCubit(
        sessionService: getIt<SessionService>(),
        sessionListService: getIt<SessionListService>(),
        projectService: getIt<ProjectService>(),
        connectionService: getIt<ConnectionService>(),
        sseEventTracker: getIt<SseEventTracker>(),
        sessionUnseenTracker: getIt<SessionUnseenTracker>(),
        routeSource: getIt<RouteSource>(),
        projectId: projectId,
        failureReporter: getIt<FailureReporter>(),
      ),
      child: child,
    );
  }
}
