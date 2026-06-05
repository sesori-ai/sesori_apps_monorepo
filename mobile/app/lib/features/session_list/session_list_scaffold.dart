import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";

import "../../core/extensions/build_context_x.dart";
import "../../l10n/app_localizations.dart";
import "session_list_content.dart";

class SessionListScaffold extends StatelessWidget {
  final String? projectName;
  final String? selectedSessionId;
  final ValueChanged<Session> onSessionTap;
  final ValueChanged<Session> onSessionLongPress;
  final ValueChanged<Session> onSessionSwipe;
  final VoidCallback onNewSession;

  const SessionListScaffold({
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

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title(loc: loc)),
            if (baseBranch != null)
              Text(
                baseBranch,
                style: context.zyra.textTheme.textXs.regular.copyWith(
                  color: context.zyra.colors.textSecondary,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(showArchived ? Icons.archive : Icons.archive_outlined),
            tooltip: loc.sessionListToggleArchived,
            onPressed: state is SessionListLoaded ? () => context.read<SessionListCubit>().toggleArchived() : null,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: onNewSession,
        tooltip: loc.sessionListNewSession,
        child: const Icon(Icons.add),
      ),
      body: SessionListContent(
        selectedSessionId: selectedSessionId,
        onSessionTap: onSessionTap,
        onSessionLongPress: onSessionLongPress,
        onSessionSwipe: onSessionSwipe,
      ),
    );
  }

  String _title({required AppLocalizations loc}) => switch (projectName) {
    final name? => loc.sessionListTitleWithName(name),
    null => loc.sessionListTitle,
  };
}
