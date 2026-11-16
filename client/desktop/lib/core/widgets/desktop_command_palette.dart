import "package:flutter/foundation.dart";
import "package:flutter/services.dart" show LogicalKeyboardKey;
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../di/injection.dart";
import "desktop_sidebar.dart";

/// One app-wide command: the palette lists it and the cockpit binds its
/// shortcut, when it has one.
class const DesktopCommand({
  required final String label,

  /// Quiet words after the label, which the palette does not search.
  final String? detail,
  required final IconData icon,
  required final SingleActivator? shortcut,
  required final VoidCallback run,
});

/// A cockpit shortcut: Cmd+[key] on macOS, Ctrl+[key] elsewhere, with Shift
/// held too when [shift] is set.
SingleActivator desktopShortcut({required LogicalKeyboardKey key, bool shift = false}) => SingleActivator(
  key,
  meta: defaultTargetPlatform == TargetPlatform.macOS,
  control: defaultTargetPlatform != TargetPlatform.macOS,
  shift: shift,
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
    // Summoned by keyboard many times a day, so it is simply there, and barely dims.
    animationStyle: AnimationStyle.noAnimation,
    barrierColor: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.28 : 0.08),
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
          create: (_) => createSessionSearchCubit(
            locator: getIt,
            window: window,
            projectInventory: projectInventory,
            excludedSessionId: null,
          ),
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
              boxShadow: [
                ...prego.shadows.xl,
                const BoxShadow(color: Color(0x66000000), offset: Offset(0, 16), blurRadius: 48),
              ],
            ),
            child: Material(
              key: const Key("desktop-command-palette"),
              color: prego.colors.bgSurface3,
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
                          keptSuffix: null,
                          detail: command.detail,
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
                          keptSuffix: null,
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
                          keptSuffix: sessionForkTitleSuffix,
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

  /// Kept whole when a long [title] ending with it is cut (see
  /// [PregoKeptSuffixText]); null cuts the title at its end.
  required final String? keptSuffix,
  required final String? detail,
  required final String? trailing,
  required final String query,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final style = prego.textTheme.textSm.regular.copyWith(color: prego.colors.textPrimary);
    final quiet = prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary);
    final matches = titleMatchRanges(title: title, query: query);
    // The title from [from] to [to], its query matches highlighted.
    TextSpan titleSpan({required int from, required int to}) {
      final spans = <TextSpan>[];
      var at = from;
      for (final range in matches) {
        final start = range.start.clamp(from, to);
        final end = range.end.clamp(from, to);
        if (start >= end) continue;
        spans
          ..add(TextSpan(text: title.substring(at, start)))
          ..add(
            TextSpan(
              text: title.substring(start, end),
              style: TextStyle(fontWeight: FontWeight.w500, color: prego.colors.textBrandSecondary),
            ),
          );
        at = end;
      }
      spans.add(TextSpan(text: title.substring(at, to)));
      return TextSpan(style: style, children: spans);
    }

    final trailing = this.trailing;
    return Row(
      children: [
        Icon(icon, size: PregoIconSize.sm, color: prego.colors.textSecondary),
        const SizedBox(width: PregoSpacing.sm),
        Expanded(
          child: switch (PregoKeptSuffixText.split(text: title, keptSuffix: keptSuffix)) {
            (:final base, suffix: _) => Semantics(
              label: title,
              excludeSemantics: true,
              child: Row(
                children: [
                  Flexible(
                    child: Text.rich(
                      titleSpan(from: 0, to: base.length),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // As wide as the cut text, so the suffix follows the ellipsis directly.
                      textWidthBasis: TextWidthBasis.longestLine,
                    ),
                  ),
                  Text.rich(titleSpan(from: base.length, to: title.length), maxLines: 1),
                ],
              ),
            ),
            null => Text.rich(titleSpan(from: 0, to: title.length), maxLines: 1, overflow: TextOverflow.ellipsis),
          },
        ),
        if (detail case final detail?)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: PregoSpacing.lg),
              child: Text(detail, style: quiet, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        if (trailing != null) ...[const SizedBox(width: PregoSpacing.sm), Text(trailing, style: quiet)],
      ],
    );
  }
}
