import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";

/// Desktop composition boundary for the shared session-diff presentation.
class const DesktopSessionDiffsScreen({
  super.key,
  required final String projectId,
  required final String sessionId,
  required final VoidCallback onBack,
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
        onBack: onBack,
        // The desktop root owns its single connection banner.
        banner: null,
      ),
    );
  }
}
