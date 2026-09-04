import "dart:async";

import "package:flutter/foundation.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart" show CommandPickerEntry, CommandPickerEntryBuilder, loge;
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../l10n/app_localizations.dart";

class const CommandPickerSheet({
  super.key,
  required final List<CommandInfo> commands,
}) extends StatefulWidget {
  static Future<CommandInfo?> show(
    BuildContext context, {
    required List<CommandInfo> commands,
  }) {
    return showPregoBottomSheet<CommandInfo>(
      context: context,
      title: context.loc.sessionDetailCommandPickerTitle,
      // Full-bleed list; rows and the search field pad themselves. The list
      // consumes the home-indicator inset as scroll padding.
      contentPadding: EdgeInsetsDirectional.zero,
      handleBottomSafeArea: false,
      bodySize: PregoBottomSheetBodySize.seventyPercent,
      builder: (_) => CommandPickerSheet(commands: commands),
    );
  }

  @override
  State<CommandPickerSheet> createState() => _CommandPickerSheetState();
}

class _CommandPickerSheetState() extends State<CommandPickerSheet> {
  String _query = "";

  /// Precomputed picker entries; `null` while the background isolate is
  /// still preparing them.
  List<CommandPickerEntry>? _entries;

  /// Entries matching [_query]. Cached so unrelated rebuilds don't re-run
  /// the filter pass; only recomputed when the entries arrive or the query
  /// changes. `null` while the entries are still loading.
  List<CommandPickerEntry>? _filtered;

  @override
  void initState() {
    super.initState();
    unawaited(_loadEntries());
  }

  Future<void> _loadEntries() async {
    List<CommandPickerEntry> entries;
    try {
      entries = await compute(_buildEntries, widget.commands);
    } catch (error, stackTrace) {
      // Fail soft: show the empty state rather than leaving the sheet stuck
      // on the spinner with an uncaught async error.
      loge("Command picker entry build failed", error, stackTrace);
      entries = const [];
    }
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _filtered = _filteredEntries(entries);
    });
  }

  /// Entry point for compute() — must be top-level or static.
  static List<CommandPickerEntry> _buildEntries(List<CommandInfo> commands) =>
      const CommandPickerEntryBuilder().build(commands: commands);

  /// Cheap single `contains` pass over precomputed lowercase haystacks —
  /// the sorting and display-string preparation already happened in the
  /// background isolate.
  List<CommandPickerEntry> _filteredEntries(List<CommandPickerEntry> entries) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return entries;
    return entries.where((entry) => entry.searchText.contains(query)).toList();
  }

  String _sourceLabel(CommandSource? source, {required AppLocalizations loc}) => switch (source) {
    CommandSource.command => loc.commandSourceCommand,
    CommandSource.mcp => loc.commandSourceMcp,
    CommandSource.skill => loc.commandSourceSkill,
    CommandSource.unknown || null => loc.commandSourceCustom,
  };

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;

    // Transparent Material so the tiles' ink paints on top of the sheet
    // surface instead of behind it on the modal's transparent Material.
    return Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: loc.sessionDetailCommandSearch,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: prego.colors.bgSurface1,
              ),
              onChanged: (value) => setState(() {
                _query = value;
                final entries = _entries;
                if (entries != null) _filtered = _filteredEntries(entries);
              }),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: switch (_filtered) {
              null => const Center(child: PregoActivityIndicator(color: null)),
              final filtered when filtered.isEmpty => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    loc.sessionDetailNoCommands,
                    textAlign: TextAlign.center,
                    style: prego.textTheme.textSm.regular.copyWith(
                      color: prego.colors.textSecondary,
                    ),
                  ),
                ),
              ),
              final filtered => ListView.separated(
                // Extend the scrollable underneath the home indicator: with
                // handleBottomSafeArea: false the sheet no longer pads for it, so
                // the bottom inset is added as scroll padding here (mirroring the
                // model picker) instead of clipping the last command above it.
                padding: EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4 + MediaQuery.paddingOf(context).bottom),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: prego.colors.borderPrimary,
                ),
                itemBuilder: (context, index) {
                  final entry = filtered[index];
                  final description = entry.displayDescription;
                  final hints = entry.displayHints;
                  return ListTile(
                    title: Text("/${entry.command.name}"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (description != null)
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (hints != null)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(top: 4),
                            child: Text(
                              hints,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: prego.textTheme.textXs.regular.copyWith(
                                color: prego.colors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: prego.colors.bgBrandPrimary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _sourceLabel(entry.command.source, loc: loc),
                        style: prego.textTheme.textXs.medium.copyWith(
                          color: prego.colors.textBrandPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    onTap: () => context.pop(entry.command),
                  );
                },
              ),
            },
          ),
        ],
      ),
    );
  }
}
