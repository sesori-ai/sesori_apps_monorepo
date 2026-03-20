import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";

import "../../../core/widgets/markdown_styles.dart";

class TextPartWidget extends StatelessWidget {
  final String text;
  final bool isStreaming;

  const TextPartWidget({
    super.key,
    required this.text,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: MarkdownBody(
        data: text,
        selectable: true,
        styleSheet: buildSessionMarkdownStyleSheet(theme),
      ),
    );
  }
}
