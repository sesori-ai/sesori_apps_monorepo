import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/widgets/desktop_page_toolbar.dart";

/// Desktop composition boundary for the shared session-diff presentation: the
/// page toolbar over the file list and the selected file's diff. The page goes
/// back with Cmd/Ctrl+[, so its toolbar has no Back.
class const DesktopSessionDiffsScreen({
  super.key,
  required final String? projectName,
  required final String sessionId,

  /// Opens the project's session list from the toolbar breadcrumb.
  required final VoidCallback onOpenProject,
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
        chrome: SessionDiffsSplit(
          headerBuilder: ({required context, required title, required summary}) => DesktopPageToolbar(
            breadcrumb: (label: projectName ?? context.loc.sessionListTitle, onPressed: onOpenProject),
            status: null,
            title: title,
            subtitle: summary == null ? null : PregoNavSubtitle(text: summary),
            actions: const [],
          ),
        ),
      ),
    );
  }
}
