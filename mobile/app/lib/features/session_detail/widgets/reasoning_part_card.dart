import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../../core/extensions/build_context_x.dart";
import "../../../core/widgets/app_modal_bottom_sheet.dart";
import "reasoning_modal.dart";

class ReasoningPartCard extends StatelessWidget {
  final String text;
  final bool isStreaming;
  final String partId;
  final String messageId;

  const ReasoningPartCard({
    super.key,
    required this.text,
    required this.isStreaming,
    required this.partId,
    required this.messageId,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty && !isStreaming) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final loc = context.loc;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showFullText(context: context),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.psychology,
                      size: 18,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isStreaming ? loc.sessionDetailThinking : loc.sessionDetailThought,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.unfold_more,
                      size: 16,
                      color: theme.colorScheme.outline,
                    ),
                  ],
                ),
              ),
              if (isStreaming && text.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 10),
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.white],
                      stops: [0.0, 0.35],
                    ).createShader(bounds),
                    blendMode: BlendMode.dstIn,
                    child: Container(
                      height: 56,
                      width: double.infinity,
                      clipBehavior: Clip.hardEdge,
                      decoration: const BoxDecoration(),
                      child: OverflowBox(
                        alignment: Alignment.bottomLeft,
                        maxHeight: double.infinity,
                        child: Text(
                          text,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else if (!isStreaming && text.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 10),
                  child: Text(
                    _firstLinePlainText(text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Extracts the first non-empty line from [markdown] and strips common
  /// markdown formatting so it renders as plain text in the preview.
  static String _firstLinePlainText(String markdown) {
    final firstLine = markdown.split('\n').firstWhere(
          (line) => line.trim().isNotEmpty,
          orElse: () => markdown,
        );
    var plain = firstLine.trim();

    // Headings: # ## ### etc.
    plain = plain.replaceAllMapped(
      RegExp(r'^#{1,6}\s*'),
      (_) => '',
    );

    // Bold / italic / strikethrough (must run before inline code)
    plain = plain.replaceAllMapped(
      RegExp(r'\*\*\*(.*?)\*\*\*'),
      (m) => m.group(1)!,
    );
    plain = plain.replaceAllMapped(
      RegExp('___(.*?)___'),
      (m) => m.group(1)!,
    );
    plain = plain.replaceAllMapped(
      RegExp(r'\*\*(.*?)\*\*'),
      (m) => m.group(1)!,
    );
    plain = plain.replaceAllMapped(
      RegExp('__(.*?)__'),
      (m) => m.group(1)!,
    );
    plain = plain.replaceAllMapped(
      RegExp(r'\*(.*?)\*'),
      (m) => m.group(1)!,
    );
    plain = plain.replaceAllMapped(
      RegExp('_(.*?)_'),
      (m) => m.group(1)!,
    );
    plain = plain.replaceAllMapped(
      RegExp('~~(.*?)~~'),
      (m) => m.group(1)!,
    );

    // Inline code: `code`
    plain = plain.replaceAllMapped(
      RegExp('`([^`]+)`'),
      (m) => m.group(1)!,
    );

    // Images: ![alt](url) → remove entirely (must run before link regex)
    plain = plain.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]+\)'), '');

    // Links: [text](url)
    plain = plain.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (m) => m.group(1)!,
    );

    // Blockquote: > text
    plain = plain.replaceAllMapped(
      RegExp(r'^>\s*'),
      (_) => '',
    );

    // Collapse multiple spaces left behind by removed elements
    plain = plain.replaceAll(RegExp(r'\s+'), ' ');

    return plain.trim();
  }

  void _showFullText({required BuildContext context}) {
    final cubit = context.read<SessionDetailCubit>();

    showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: ReasoningModal(
          partId: partId,
          messageId: messageId,
        ),
      ),
    );
  }
}
