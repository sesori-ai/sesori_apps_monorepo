import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:markdown/markdown.dart" as md;
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

const _fieldChangeTag = "field-change";

/// Reads a line the bridge writes for a task update's changed field,
/// `Label: ~~old~~ → new`, as its own block, so [PermissionFieldChangeBuilder]
/// can show it as a table row. The values arrive Markdown-escaped, and an
/// escaped value cannot hold the `~~` that ends the old one.
class PermissionFieldChangeSyntax() extends md.BlockSyntax {
  static final _line = RegExp(r"^([A-Z][A-Za-z ]*): ~~((?:\\.|[^\\~])+)~~ → (.+)$");

  @override
  RegExp get pattern => _line;

  @override
  md.Node? parse(md.BlockParser parser) {
    final match = _line.firstMatch(parser.current.content);
    if (match == null) return null;
    parser.advance();
    String part(int group) => _unescape(text: match.group(group) ?? "");
    return md.Element.empty(_fieldChangeTag)..attributes.addAll({"label": part(1), "old": part(2), "new": part(3)});
  }

  String _unescape({required String text}) =>
      text.replaceAllMapped(RegExp(r"\\(.)"), (escape) => escape.input.substring(escape.start + 1, escape.end));
}

/// Shows the blocks [PermissionFieldChangeSyntax] reads as table rows: the
/// field's label in a column of its own, its old value struck through above
/// the new one.
class PermissionFieldChangeBuilder() extends MarkdownElementBuilder {
  static const tag = _fieldChangeTag;

  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return _FieldChangeRow(
      label: element.attributes["label"] ?? "",
      old: element.attributes["old"] ?? "",
      updated: element.attributes["new"] ?? "",
    );
  }
}

class const _FieldChangeRow({required final String label, required final String old, required final String updated})
    extends StatelessWidget {
  /// Wide enough for a short label on one line; a longer one wraps.
  static const _labelWidth = 96.0;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final valueStyle = prego.textTheme.code.copyWith(color: prego.colors.textPrimary);
    return Container(
      padding: EdgeInsets.only(bottom: prego.spacing.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: prego.colors.borderSecondary)),
      ),
      child: SelectionArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: prego.spacing.md,
          children: [
            SizedBox(
              width: _labelWidth,
              child: Text(label, style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textSecondary)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: prego.spacing.xxs,
                children: [
                  Text(
                    old,
                    style: oldValueStyle(prego: prego, style: valueStyle),
                  ),
                  Text(updated, style: valueStyle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [style] struck through with a thick red line, for a value a change
/// replaces; the line stays clear on both themes.
TextStyle oldValueStyle({required PregoDesignSystem prego, required TextStyle style}) => style.copyWith(
  color: prego.colors.textSecondary,
  decoration: TextDecoration.lineThrough,
  decorationColor: prego.colors.fgErrorPrimary,
  decorationThickness: 2,
);
