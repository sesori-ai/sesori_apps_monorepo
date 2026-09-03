import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";

/// Mobile composition boundary for the shared session-diff presentation.
class const SessionDiffsScreen({
  super.key,
  required final String projectId,
  required final String sessionId,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DiffCubit(
        sessionRepository: getIt<SessionRepository>(),
        connectionService: getIt<ConnectionService>(),
        loadedStateAnalyticsReporter: LoadedStateAnalyticsReporter.sessionDiff(
          productAnalyticsService: getIt<ProductAnalyticsService>(),
        ),
        sessionId: sessionId,
        staleRetryDelay: const Duration(seconds: 5),
      ),
      child: SessionDiffsView(
        onBack: null,
        banner: ConnectionBanner.maybeFor(context),
      ),
    );
  }
}
