import "package:flutter/widgets.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/di/injection.dart";

class SessionListCubitProvider extends StatelessWidget {
  final String projectId;
  final Widget child;

  SessionListCubitProvider({
    required this.projectId,
    required this.child,
  }) : super(key: ValueKey("session-list-cubit-$projectId"));

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SessionListCubit(
        sessionService: getIt<SessionService>(),
        projectService: getIt<ProjectService>(),
        connectionService: getIt<ConnectionService>(),
        sseEventRepository: getIt<SseEventRepository>(),
        routeSource: getIt<RouteSource>(),
        projectId: projectId,
        failureReporter: getIt<FailureReporter>(),
      ),
      child: child,
    );
  }
}
