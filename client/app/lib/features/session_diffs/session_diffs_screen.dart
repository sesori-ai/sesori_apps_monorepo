import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";
import "session_diffs_body.dart";

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
        productAnalyticsService: getIt<ProductAnalyticsService>(),
        sessionId: sessionId,
      ),
      // SessionDiffsBody owns the PregoGlassScaffold so its bar subtitle can
      // react to the loaded file/addition/deletion stats.
      child: const SessionDiffsBody(),
    );
  }
}
