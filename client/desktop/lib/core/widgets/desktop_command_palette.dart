import "package:flutter/foundation.dart";
import "package:flutter/services.dart" show LogicalKeyboardKey;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "desktop_sidebar.dart";

/// One app-wide command: the cockpit binds its shortcut and the palette lists it.
class const DesktopCommand({
  required final String label,
  required final IconData icon,
  required final SingleActivator shortcut,
  required final VoidCallback run,
});

/// A cockpit shortcut: Cmd+[key] on macOS, Ctrl+[key] elsewhere.
SingleActivator desktopShortcut({required LogicalKeyboardKey key}) => SingleActivator(
  key,
  meta: defaultTargetPlatform == TargetPlatform.macOS,
  control: defaultTargetPlatform != TargetPlatform.macOS,
  includeRepeats: false,
);

/// How a [desktopShortcut] reads: "⌘N" on macOS, "Ctrl+N" elsewhere.
String desktopShortcutLabel({required SingleActivator shortcut}) {
  final key = shortcut.trigger.keyLabel;
  return defaultTargetPlatform == TargetPlatform.macOS ? "⌘$key" : "Ctrl+$key";
}

typedef _PaletteSession = ({ProjectSummary project, String projectName, Session session});

/// Opens the palette over [commands] and the cockpit's projects and recent
/// sessions, as they stand now: rows that moved under the highlight would
/// make Enter pick something else. A pick closes the palette, then acts.
Future<void> showDesktopCommandPalette({
  required BuildContext context,
  required List<DesktopCommand> commands,
  required SidebarSessionOpenedCallback onOpenSession,
  required ProjectOpenedCallback onOpenProject,
}) {
  final projectState = context.read<ProjectListCubit>().state;
  final projects = projectState is ProjectListLoaded ? projectState.projects : const <ProjectSummary>[];
  final projectById = {for (final project in projects) project.id: project};
  final sessions = <_PaletteSession>[
    for (final MapEntry(key: projectId, value: entry) in context.read<RecentSessionsCubit>().state.entries)
      if ((projectById[projectId], entry) case (final project?, RecentSessionsLoaded(:final visibleSessions)))
        for (final session in visibleSessions)
          (
            project: project,
            projectName: desktopProjectDisplayName(context: context, project: project),
            session: session,
          ),
  ]..sort((a, b) => (b.session.time?.updated ?? 0).compareTo(a.session.time?.updated ?? 0));
  return showDialog<void>(
    context: context,
    animationStyle: prefersReducedMotion(context) ? AnimationStyle.noAnimation : null,
    builder: (dialogContext) {
      void pick(VoidCallback action) {
        Navigator.pop(dialogContext);
        action();
      }

      return _CommandPalette(
        commands: commands,
        sessions: sessions,
        projects: [
          for (final project in projects)
            (project: project, name: desktopProjectDisplayName(context: context, project: project)),
        ],
        onClose: () => Navigator.pop(dialogContext),
        onPickCommand: (command) => pick(command.run),
        onPickSession: (item) => pick(
          () => onOpenSession(
            context: context,
            project: item.project,
            displayName: item.projectName,
            session: item.session,
          ),
        ),
        onPickProject: (project) => pick(
          () => onOpenProject(context: context, project: project.project, displayName: project.name),
        ),
      );
    },
  );
}

class const _CommandPalette({
  required final List<DesktopCommand> commands,
  required final List<_PaletteSession> sessions,
  required final List<({ProjectSummary project, String name})> projects,
  required final VoidCallback onClose,
  required final ValueChanged<DesktopCommand> onPickCommand,
  required final ValueChanged<_PaletteSession> onPickSession,
  required final ValueChanged<({ProjectSummary project, String name})> onPickProject,
}) extends StatefulWidget {
  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState() extends State<_CommandPalette> {
  String _query = "";

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final commands = matchTitles(items: widget.commands, titleOf: (command) => command.label, query: _query);
    final sessions = matchTitles(items: widget.sessions, titleOf: (item) => item.session.title, query: _query);
    final projects = matchTitles(items: widget.projects, titleOf: (project) => project.name, query: _query);
    final rows = <PregoPickerSearchRow>[
      if (commands.isNotEmpty) PregoPickerSearchHeading(text: loc.desktopCommandPaletteCommands),
      for (final command in commands)
        PregoPickerSearchOption(
          isSelected: false,
          onPick: () => widget.onPickCommand(command),
          child: _PaletteRow(
            icon: command.icon,
            title: command.label,
            detail: null,
            trailing: desktopShortcutLabel(shortcut: command.shortcut),
            query: _query,
          ),
        ),
      if (sessions.isNotEmpty) PregoPickerSearchHeading(text: loc.sessionListTitle),
      for (final item in sessions)
        PregoPickerSearchOption(
          isSelected: false,
          onPick: () => widget.onPickSession(item),
          child: _PaletteRow(
            icon: TablerRegular.message,
            title: item.session.title ?? loc.sessionListUntitled,
            detail: item.projectName,
            trailing: null,
            query: _query,
          ),
        ),
      if (projects.isNotEmpty) PregoPickerSearchHeading(text: loc.projectListTitle),
      for (final project in projects)
        PregoPickerSearchOption(
          isSelected: false,
          onPick: () => widget.onPickProject(project),
          child: _PaletteRow(
            icon: TablerRegular.folder,
            title: project.name,
            detail: null,
            trailing: null,
            query: _query,
          ),
        ),
    ];
    return Align(
      alignment: AlignmentDirectional.topCenter,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: 96, start: PregoSpacing.lg, end: PregoSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 440),
          // The composer popovers' surface, which the search list is built for.
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PregoRadius.lg),
              boxShadow: prego.shadows.xl,
            ),
            child: Material(
              key: const Key("desktop-command-palette"),
              color: prego.colors.bgSecondary,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PregoRadius.lg),
                side: BorderSide(color: prego.colors.borderSecondary, width: 0.5),
              ),
              child: PregoPickerSearchList(
                searchHint: loc.desktopCommandPaletteHint,
                onQueryChanged: (query) => setState(() => _query = query),
                rows: rows,
                emptyText: loc.listSearchNoMatches,
                onClose: widget.onClose,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class const _PaletteRow({
  required final IconData icon,
  required final String title,
  required final String? detail,
  required final String? trailing,
  required final String query,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final style = prego.textTheme.textSm.regular.copyWith(color: prego.colors.textPrimary);
    final quiet = prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary);
    final spans = <TextSpan>[];
    var at = 0;
    for (final range in titleMatchRanges(title: title, query: query)) {
      spans
        ..add(TextSpan(text: title.substring(at, range.start)))
        ..add(
          TextSpan(
            text: title.substring(range.start, range.end),
            style: TextStyle(fontWeight: FontWeight.w600, color: prego.colors.textBrandSecondary),
          ),
        );
      at = range.end;
    }
    spans.add(TextSpan(text: title.substring(at)));
    if (detail case final detail?) spans.add(TextSpan(text: "   $detail", style: quiet));
    final trailing = this.trailing;
    return Row(
      children: [
        Icon(icon, size: PregoIconSize.sm, color: prego.colors.textSecondary),
        const SizedBox(width: PregoSpacing.sm),
        Expanded(
          child: Text.rich(
            TextSpan(style: style, children: spans),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: PregoSpacing.sm), Text(trailing, style: quiet)],
      ],
    );
  }
}
