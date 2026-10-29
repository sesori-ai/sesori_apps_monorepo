import "package:flutter/foundation.dart";
import "package:flutter/services.dart" show LogicalKeyboardKey;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "desktop_sidebar.dart";

/// One app-wide command: the palette lists it and the cockpit binds its
/// shortcut, when it has one.
class const DesktopCommand({
  required final String label,
  required final IconData icon,
  required final SingleActivator? shortcut,
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

/// Opens the palette over [commands], the cockpit's projects and the sessions
/// of every project, whatever the sidebar list's filter, search and chip. The
/// commands and projects are those that stand now; the sessions come from a
/// [SessionSearchCubit] and sit last, so its later answers only change rows
/// below the ones already read. A pick closes the palette, then acts; a
/// project pick filters the sidebar's list to it.
Future<void> showDesktopCommandPalette({
  required BuildContext context,
  required List<DesktopCommand> commands,
  required SidebarSessionOpenedCallback onOpenSession,
  required void Function({required String projectId}) onSelectProject,
}) {
  final projectState = context.read<ProjectListCubit>().state;
  final projects = projectState is ProjectListLoaded ? projectState.projects : const <ProjectSummary>[];
  // The dialog's route sits above the session scope, so its owners are read here.
  final window = context.read<SessionWindowService>();
  final projectInventory = context.read<ProjectInventoryService>();
  final authGate = context.read<AuthGateCubit>();
  // ignore: no_slop_linter/avoid_raw_modal_presenters, a desktop-only Spotlight-style command palette overlay, not a sheet or dialog
  return showDialog<void>(
    context: context,
    animationStyle: prefersReducedMotion(context) ? AnimationStyle.noAnimation : null,
    builder: (dialogContext) {
      // The dialog's own route, which the router's typed pop does not own.
      void close() => ModalRoute.of(dialogContext)?.navigator?.pop();
      void pick(VoidCallback action) {
        close();
        action();
      }

      // Signing out disposes the cockpit under this root dialog; it leaves too.
      return BlocListener<AuthGateCubit, AuthGateState>(
        bloc: authGate,
        listenWhen: (_, state) => state is AuthGateSignedOut,
        listener: (_, _) => close(),
        child: BlocProvider(
          create: (_) => SessionSearchCubit(window: window, projectInventory: projectInventory),
          child: _CommandPalette(
            commands: commands,
            projects: [
              for (final project in projects)
                (project: project, name: desktopProjectDisplayName(context: context, project: project)),
            ],
            onClose: close,
            onPickCommand: (command) => pick(command.run),
            onPickSession: (match) => pick(
              () => onOpenSession(
                context: context,
                project: match.project,
                displayName: desktopProjectDisplayName(context: context, project: match.project),
                session: match.session,
              ),
            ),
            onPickProject: (project) => pick(() => onSelectProject(projectId: project.project.id)),
          ),
        ),
      );
    },
  );
}

class const _CommandPalette({
  required final List<DesktopCommand> commands,
  required final List<({ProjectSummary project, String name})> projects,
  required final VoidCallback onClose,
  required final ValueChanged<DesktopCommand> onPickCommand,
  required final ValueChanged<SessionSearchMatch> onPickSession,
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
    final projects = matchTitles(items: widget.projects, titleOf: (project) => project.name, query: _query);
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
              // An answer that changes nothing keeps the rows, and with them
              // the highlight.
              child: BlocBuilder<SessionSearchCubit, SessionSearchState>(
                buildWhen: (previous, current) =>
                    !identical(previous.matches, current.matches) ||
                    (current.matches.isEmpty && previous.isSearching != current.isSearching),
                builder: (context, search) => PregoPickerSearchList(
                  searchHint: loc.desktopCommandPaletteHint,
                  onQueryChanged: (query) {
                    setState(() => _query = query);
                    context.read<SessionSearchCubit>().setQuery(query: query);
                  },
                  footer: null,
                  rows: [
                    if (commands.isNotEmpty) PregoPickerSearchHeading(text: loc.desktopCommandPaletteCommands),
                    for (final command in commands)
                      PregoPickerSearchOption(
                        isSelected: false,
                        onPick: () => widget.onPickCommand(command),
                        child: _PaletteRow(
                          icon: command.icon,
                          title: command.label,
                          detail: null,
                          trailing: switch (command.shortcut) {
                            final shortcut? => desktopShortcutLabel(shortcut: shortcut),
                            null => null,
                          },
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
                    if (search.matches.isNotEmpty) PregoPickerSearchHeading(text: loc.sessionListTitle),
                    for (final match in search.matches)
                      PregoPickerSearchOption(
                        isSelected: false,
                        onPick: () => widget.onPickSession(match),
                        child: _PaletteRow(
                          icon: TablerRegular.message,
                          title: match.session.title ?? loc.sessionListUntitled,
                          detail: desktopProjectDisplayName(context: context, project: match.project),
                          trailing: null,
                          query: _query,
                        ),
                      ),
                  ],
                  // Until the bridge answers, nothing matching yet is not "no matches".
                  emptyText: search.isSearching ? null : loc.listSearchNoMatches,
                  onClose: widget.onClose,
                ),
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
