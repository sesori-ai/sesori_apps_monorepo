import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";
import "session_diffs_body.dart";

class SessionDiffsScreen extends StatelessWidget {
  final String projectId;
  final String sessionId;

  const SessionDiffsScreen({
    super.key,
    required this.projectId,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DiffCubit(
        sessionRepository: getIt<SessionRepository>(),
        sessionId: sessionId,
      ),
      // SessionDiffsBody owns the PregoGlassScaffold so its bar subtitle can
      // react to the loaded file/addition/deletion stats.
      child: const SessionDiffsBody(),
    );
  }
}
