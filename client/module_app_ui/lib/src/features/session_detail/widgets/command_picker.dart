import "dart:async";

import "package:flutter/foundation.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart" show CommandPickerEntry, CommandPickerEntryBuilder, loge;
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../l10n/app_localizations.dart";

/// The composer's slash-command picker, filtered by the search.
///
/// A spinner shows while a background isolate sorts and prepares the catalog,
/// so opening never blocks on a catalog of hundreds of commands.
class const CommandPicker({
  super.key,
  required final List<CommandInfo> commands,
  required final ValueChanged<CommandInfo> onCommandSelected,
  required final VoidCallback onClose,
}) extends StatefulWidget {
  @override
  State<CommandPicker> createState() => _CommandPickerState();
}

class _CommandPickerState() extends State<CommandPicker> {
  String _query = "";

  /// Precomputed picker entries; `null` while the background isolate is
  /// still preparing them.
  List<CommandPickerEntry>? _entries;

  /// The rows matching [_query], kept until it changes; `null` while the
  /// entries load.
  List<PregoPickerSearchRow>? _rows;

  @override
  void initState() {
    super.initState();
    unawaited(_loadEntries());
  }

  @override
  void didUpdateWidget(CommandPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The session refreshed its catalog under the open picker.
    if (!identical(oldWidget.commands, widget.commands)) unawaited(_loadEntries());
  }

  Future<void> _loadEntries() async {
    final commands = widget.commands;
    List<CommandPickerEntry> entries;
    try {
      entries = await compute(_buildEntries, commands);
    } catch (error, stackTrace) {
      // Fail soft: show the empty state rather than leaving the picker stuck
      // on the spinner with an uncaught async error.
      loge("Command picker entry build failed", error, stackTrace);
      entries = const [];
    }
    // A newer catalog arrived while this one loaded.
    if (!mounted || !identical(commands, widget.commands)) return;
    setState(() {
      _entries = entries;
      _rows = _rowsFor(entries: entries);
    });
  }

  /// Entry point for compute() — must be top-level or static.
  static List<CommandPickerEntry> _buildEntries(List<CommandInfo> commands) =>
      const CommandPickerEntryBuilder().build(commands: commands);

  /// A cheap `contains` pass over precomputed lowercase haystacks; the sorting
  /// and display strings were prepared in the background isolate.
  List<PregoPickerSearchRow> _rowsFor({required List<CommandPickerEntry> entries}) => [
    for (final entry in entries)
      if (_query.isEmpty || entry.searchText.contains(_query))
        PregoPickerSearchOption(
          isSelected: false,
          onPick: () => widget.onCommandSelected(entry.command),
          child: _CommandLabel(entry: entry),
        ),
  ];

  void _setQuery(String query) => setState(() {
    _query = query;
    final entries = _entries;
    if (entries != null) _rows = _rowsFor(entries: entries);
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return PregoPickerSearchList(
      searchHint: loc.sessionDetailCommandSearch,
      onQueryChanged: _setQuery,
      rows: _rows,
      emptyText: loc.sessionDetailNoCommands,
      onClose: widget.onClose,
    );
  }
}

/// A command's name and source, then its description and argument hints.
class const _CommandLabel({required final CommandPickerEntry entry}) extends StatelessWidget {
  String _sourceLabel({required CommandSource? source, required AppLocalizations loc}) => switch (source) {
    CommandSource.command => loc.commandSourceCommand,
    CommandSource.mcp => loc.commandSourceMcp,
    CommandSource.skill => loc.commandSourceSkill,
    CommandSource.unknown || null => loc.commandSourceCustom,
  };

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final description = entry.displayDescription;
    final hints = entry.displayHints;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: [
        Wrap(
          spacing: PregoSpacing.md,
          runSpacing: PregoSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              "/${entry.command.name}",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textPrimary),
            ),
            PregoTag(
              label: _sourceLabel(source: entry.command.source, loc: loc),
            ),
          ],
        ),
        if (description != null)
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary),
          ),
        if (hints != null)
          Text(
            hints,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary),
          ),
      ],
    );
  }
}
