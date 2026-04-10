import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../../core/extensions/build_context_x.dart";
import "../../../core/widgets/markdown_styles.dart";

/// Modal body for displaying AI reasoning/thinking content.
///
/// Self-subscribes to [SessionDetailCubit] via [context.select] for
/// real-time streaming updates — replaces the stale ValueNotifier pattern.
class ReasoningModal extends StatefulWidget {
  final String partId;
  final String messageId;

  const ReasoningModal({
    super.key,
    required this.partId,
    required this.messageId,
  });

  @override
  State<ReasoningModal> createState() => _ReasoningModalState();
}

class _ReasoningModalState extends State<ReasoningModal> {
  final ScrollController _scrollController = ScrollController();
  bool _following = true;
  bool _sheetOpen = true;

  @override
  void dispose() {
    _sheetOpen = false;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.select<SessionDetailCubit, ({String text, bool isStreaming})>(
      (cubit) => cubit.state.resolvePartContent(
        partId: widget.partId,
        messageId: widget.messageId,
      ),
    );

    final theme = Theme.of(context);
    final loc = context.loc;
    final height = MediaQuery.of(context).size.height * 0.7;

    if (_following && data.isStreaming) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_sheetOpen || !_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      });
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.psychology,
                  size: 20,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Text(
                  data.isStreaming ? loc.sessionDetailThinking : loc.sessionDetailThought,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontStyle: .italic,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollUpdateNotification && notification.dragDetails != null && _following) {
                      final pos = _scrollController.position;
                      if (pos.pixels < pos.maxScrollExtent - 20) {
                        setState(() => _following = false);
                      }
                    }
                    return false;
                  },
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      MarkdownBody(
                        data: data.text,
                        selectable: true,
                        onTapLink: handleMarkdownLinkTap,
                        styleSheet: buildSessionMarkdownStyleSheet(
                          theme,
                          paragraphStyle: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_following && data.isStreaming) _buildFollowFab(theme: theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowFab({required ThemeData theme}) {
    return Positioned(
      bottom: 12,
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(20),
          color: theme.colorScheme.primaryContainer,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              setState(() => _following = true);
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Row(
                mainAxisSize: .min,
                children: [
                  Icon(
                    Icons.arrow_downward,
                    size: 16,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.loc.sessionDetailFollowOutput,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
