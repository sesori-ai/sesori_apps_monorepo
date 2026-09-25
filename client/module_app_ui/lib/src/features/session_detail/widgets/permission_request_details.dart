import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../platform/external_link_opener.dart";
import "../../../utils/copy_text_to_clipboard.dart";
import "../../../widgets/markdown_styles.dart";

/// Renders only plugin-normalized details; tool names and Markdown are never
/// classified in the client. All request text remains selectable/copyable.
class const PermissionRequestDetails({
  super.key,
  required final SesoriPermissionAsked permission,
  required final ExternalLinkOpener openExternalLink,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final details = permission.details;
    final command = switch (details) {
      CommandPermissionDetails(:final command) => command,
      NetworkPermissionDetails(:final command) => command,
      GenericPermissionDetails() || FileChangesPermissionDetails() => null,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: prego.spacing.lg,
      children: [
        if (details case FileChangesPermissionDetails(:final files))
          PregoGroupedRows(
            color: Colors.transparent,
            children: [
              for (final file in files)
                PregoGroupedRow(
                  horizontalPadding: 0,
                  icon: TablerRegular.file,
                  title: SelectableText(file.path.split(RegExp(r"[/\\]")).last),
                  subtitle: SelectableText(file.path),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (file.operation case final operation?)
                        Text(switch (operation) {
                          PermissionFileOperation.create => context.loc.permissionFileCreate,
                          PermissionFileOperation.write => context.loc.permissionFileWrite,
                          PermissionFileOperation.delete => context.loc.permissionFileDelete,
                        }, style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary)),
                      PregoCopyIconButton(
                        onCopy: () => copyTextToClipboard(text: file.path, operation: "permission file path"),
                        tooltip: context.loc.sessionDetailCopy,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        if (details case NetworkPermissionDetails(:final targets))
          PregoGroupedRows(
            color: Colors.transparent,
            children: [
              for (final target in targets)
                PregoGroupedRow(
                  horizontalPadding: 0,
                  icon: TablerRegular.world,
                  title: SelectableText(context.loc.permissionNetworkTarget(target)),
                  trailing: PregoCopyIconButton(
                    onCopy: () => copyTextToClipboard(text: target, operation: "permission network target"),
                    tooltip: context.loc.sessionDetailCopy,
                  ),
                ),
            ],
          ),
        if (command != null) _detailCard(context: context, text: command, literal: true),
        if (permission.description != command)
          _detailCard(context: context, text: permission.description, literal: false),
      ],
    );
  }

  Widget _detailCard({required BuildContext context, required String text, required bool literal}) {
    final prego = context.prego;
    final style = prego.textTheme.code.copyWith(color: prego.colors.textPrimary);
    return Container(
      key: Key(literal ? "permission-command-detail" : "permission-request-detail"),
      padding: EdgeInsets.all(prego.spacing.lg),
      decoration: BoxDecoration(
        color: prego.colors.bgSurface2,
        borderRadius: BorderRadius.circular(prego.radius.xl),
        border: Border.all(color: prego.colors.borderPrimary),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  permission.tool,
                  style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textSecondary),
                ),
              ),
              PregoCopyIconButton(
                onCopy: () => copyTextToClipboard(
                  text: text,
                  operation: literal ? "permission command" : "permission description",
                ),
                tooltip: context.loc.sessionDetailCopy,
              ),
            ],
          ),
          SizedBox(height: prego.spacing.md),
          if (literal)
            SelectableText(text, style: style)
          else
            MarkdownBody(
              data: text,
              selectable: true,
              onTapLink: buildMarkdownLinkTapHandler(openExternalLink: openExternalLink),
              styleSheet: buildSessionMarkdownStyleSheet(prego: prego, paragraphStyle: style).copyWith(
                codeblockDecoration: BoxDecoration(
                  color: prego.colors.bgSurface1,
                  borderRadius: BorderRadius.circular(prego.radius.md),
                  border: Border.all(color: prego.colors.borderSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
