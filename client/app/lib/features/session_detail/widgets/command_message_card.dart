import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";
import "../../../core/extensions/text_style_x.dart";
import "command_formatter.dart";
import "command_modal.dart";

class CommandMessageCard extends StatelessWidget {
  static const resultPreviewKey = Key("command-message-result-preview");

  final String messageId;
  final CommandMessageInfo command;
  final String? resultText;

  const CommandMessageCard({
    super.key,
    required this.messageId,
    required this.command,
    required this.resultText,
  });

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final fullCommand = CommandFormatter.format(command);
    final origin = _originLabel(context: context, origin: command.origin);
    final preview = resultText?.trim() ?? "";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Semantics(
        button: true,
        label: "${loc.sessionDetailCommand}: $fullCommand, $origin",
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => CommandModal.show(
              context,
              messageId: messageId,
              command: command,
            ),
            child: Ink(
              decoration: BoxDecoration(
                color: prego.colors.bgSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: prego.colors.borderSecondary),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.terminal,
                        size: 18,
                        color: prego.colors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loc.sessionDetailCommand,
                          style: prego.textTheme.textXs.medium.copyWith(
                            color: prego.colors.textSecondary,
                          ),
                        ),
                      ),
                      _OriginLabel(label: origin),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.unfold_more,
                        size: 16,
                        color: prego.colors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fullCommand,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: prego.textTheme.textSm.bold.monospace.copyWith(
                      color: prego.colors.textPrimary,
                    ),
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      key: resultPreviewKey,
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: prego.colors.bgQuaternary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: prego.textTheme.textXs.regular.copyWith(
                          color: prego.colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OriginLabel extends StatelessWidget {
  final String label;

  const _OriginLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: prego.colors.bgBrandPrimary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: prego.textTheme.textXs.medium.copyWith(
          color: prego.colors.textBrandPrimary,
        ),
      ),
    );
  }
}

String _originLabel({required BuildContext context, required CommandOrigin origin}) => switch (origin) {
  CommandOrigin.manual => context.loc.sessionDetailCommandOriginManual,
  CommandOrigin.automatic => context.loc.sessionDetailCommandOriginAutomatic,
  CommandOrigin.unknown => context.loc.sessionDetailCommandOriginUnknown,
};
