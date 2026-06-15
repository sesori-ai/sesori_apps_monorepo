import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
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
      child: Scaffold(
        appBar: AppBar(title: const _DiffStatsTitle()),
        body: const SessionDiffsBody(),
      ),
    );
  }
}

/// App bar title showing "File changes" plus a files/additions/deletions
/// summary line once the diff has loaded.
class _DiffStatsTitle extends StatelessWidget {
  const _DiffStatsTitle();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiffCubit, DiffState>(
      buildWhen: (prev, curr) => _getStats(prev) != _getStats(curr),
      builder: (context, state) {
        final (fileCount, additions, deletions) = _getStats(state);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.loc.diffFileChangesTitle),
            if (fileCount > 0)
              Text(
                context.loc.diffFilesChangedCount(
                  fileCount,
                  additions,
                  deletions,
                ),
                style: context.prego.textTheme.textXs.regular,
              ),
          ],
        );
      },
    );
  }

  static (int, int, int) _getStats(DiffState state) {
    if (state is! DiffStateLoaded) return (0, 0, 0);
    var adds = 0;
    var dels = 0;
    for (final f in state.files) {
      if (f is FileDiffContent) {
        adds += f.additions;
        dels += f.deletions;
      }
    }
    return (state.files.length, adds, dels);
  }
}
