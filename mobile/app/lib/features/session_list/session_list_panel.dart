import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";

import "../../core/extensions/build_context_x.dart";
import "../../l10n/app_localizations.dart";
import "session_list_content.dart";

class SessionListPanel extends StatelessWidget {
  final String? projectName;
  final String? selectedSessionId;
  final ValueChanged<Session> onSessionTap;
  final ValueChanged<Session> onSessionLongPress;
  final ValueChanged<Session> onSessionSwipe;
  final VoidCallback onNewSession;

  const SessionListPanel({
    super.key,
    this.projectName,
    this.selectedSessionId,
    required this.onSessionTap,
    required this.onSessionLongPress,
    required this.onSessionSwipe,
    required this.onNewSession,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = context.watch<SessionListCubit>().state;
    final showArchived = state is SessionListLoaded && state.showArchived;
    final baseBranch = state is SessionListLoaded ? state.baseBranch : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _title(loc: loc),
                      style: context.zyra.textTheme.textMd.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(showArchived ? Icons.archive : Icons.archive_outlined),
                    tooltip: loc.sessionListToggleArchived,
                    onPressed: state is SessionListLoaded
                        ? () => context.read<SessionListCubit>().toggleArchived()
                        : null,
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: onNewSession,
                    icon: const Icon(Icons.add),
                    label: Text(loc.sessionListNewSession),
                  ),
                ],
              ),
              if (baseBranch != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 2),
                  child: Text(
                    baseBranch,
                    style: context.zyra.textTheme.textXs.regular.copyWith(
                      color: context.zyra.colors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SessionListContent(
            selectedSessionId: selectedSessionId,
            onSessionTap: onSessionTap,
            onSessionLongPress: onSessionLongPress,
            onSessionSwipe: onSessionSwipe,
          ),
        ),
      ],
    );
  }

  String _title({required AppLocalizations loc}) => switch (projectName) {
    final name? => loc.sessionListTitleWithName(name),
    null => loc.sessionListTitle,
  };
}
