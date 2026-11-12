import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../widgets/markdown_styles.dart";
import "../session_detail_markdown_link_handler.dart";

/// Inline error display for a [MessageError].
///
/// Uses the transcript's leading alignment and body typography, with error
/// colour to distinguish a terminal failure from ongoing retry activity.
///
/// The text renders as Markdown, as every other transcript body does: a
/// harness may phrase its failure copy with inline code or emphasis. Line
/// breaks stay where the text put them, so multi-line provider output keeps
/// its shape.
class const ErrorMessageCard({
  super.key,
  required final MessageError message,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final color = prego.colors.fgErrorPrimary;
    final sheet = buildSessionMarkdownStyleSheet(
      prego: prego,
      paragraphStyle: prego.textTheme.textSm.regular.copyWith(color: color),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: MarkdownBody(
          data: message.errorMessage,
          softLineBreak: true,
          onTapLink: buildSessionDetailMarkdownLinkTapHandler(context: context),
          styleSheet: sheet.copyWith(code: sheet.code?.copyWith(color: color)),
          blockSyntaxes: sessionMarkdownBlockSyntaxes,
        ),
      ),
    );
  }
}
