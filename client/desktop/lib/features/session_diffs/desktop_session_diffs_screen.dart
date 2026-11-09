import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/widgets/desktop_page_toolbar.dart";

/// Desktop composition boundary for the shared session-diff presentation: the
/// page toolbar over the file list and the selected file's diff. Its breadcrumb
/// returns to the session, as Cmd/Ctrl+[ does.
class const DesktopSessionDiffsScreen({
  super.key,
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
        chrome: SessionDiffsSplit(
          headerBuilder: ({required context, required title, required summary}) => DesktopPageToolbar(
            breadcrumb: (
              // The session's own title, once the sidebar's list names it.
              label:
                  context.select(
                    (AllSessionsCubit cubit) =>
                        cubit.state.rows.where((row) => row.session.id == sessionId).firstOrNull?.session.title,
                  ) ??
                  context.loc.desktopSessionBreadcrumb,
              onPressed: onBack,
            ),
            status: null,
            title: title,
            titleDetail: null,
            subtitle: null,
            actions: [
              if (summary case (:final files, :final additions, :final deletions)) ...[
                PregoNavSubtitle(text: files),
                DiffCounts(
                  additions: additions,
                  deletions: deletions,
                  style: context.prego.textTheme.textXs.regular,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
