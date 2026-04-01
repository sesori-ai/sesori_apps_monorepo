import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../extensions/build_context_x.dart";
import "app_modal_bottom_sheet.dart";

class CommandPickerSheet extends StatefulWidget {
  final List<CommandInfo> commands;

  const CommandPickerSheet({
    super.key,
    required this.commands,
  });

  static Future<CommandInfo?> show(
    BuildContext context, {
    required List<CommandInfo> commands,
  }) {
    return showAppModalBottomSheet<CommandInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height * 0.7;
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: CommandPickerSheet(commands: commands),
        );
      },
    );
  }

  @override
  State<CommandPickerSheet> createState() => _CommandPickerSheetState();
}

class _CommandPickerSheetState extends State<CommandPickerSheet> {
  String _query = "";

  List<CommandInfo> get _filteredCommands {
    final sorted = [...widget.commands]..sort((a, b) => a.name.compareTo(b.name));
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return sorted;
    return sorted.where((command) {
      final hintsText = command.hints.join(" ").toLowerCase();
      return command.name.toLowerCase().contains(query) ||
          (command.description?.toLowerCase().contains(query) ?? false) ||
          hintsText.contains(query);
    }).toList();
  }

  String _sourceLabel(CommandSource? source) => switch (source) {
    CommandSource.command => "Command",
    CommandSource.mcp => "MCP",
    CommandSource.skill => "Skill",
    CommandSource.unknown || null => "Custom",
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;
    final commands = _filteredCommands;

    return Column(
      children: [
        Center(
          child: Container(
            margin: const EdgeInsetsDirectional.only(top: 12, bottom: 8),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            loc.sessionDetailCommandPickerTitle,
            style: theme.textTheme.titleMedium,
          ),
        ),
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
              fillColor: theme.colorScheme.surfaceContainerHighest,
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: switch (commands.isEmpty) {
            true => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  loc.sessionDetailNoCommands,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            false => ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: commands.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant,
              ),
              itemBuilder: (context, index) {
                final command = commands[index];
                final description = command.description?.trim();
                final hints = command.hints.where((hint) => hint.trim().isNotEmpty).join("  •  ");
                return ListTile(
                  title: Text("/${command.name}"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (description != null && description.isNotEmpty)
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (hints.isNotEmpty)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(top: 4),
                          child: Text(
                            hints,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _sourceLabel(command.source),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  onTap: () => context.pop(command),
                );
              },
            ),
          },
        ),
      ],
    );
  }
}
