import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";

import "../../../core/extensions/build_context_x.dart";
import "../../../core/widgets/app_modal_bottom_sheet.dart";
import "../../../core/widgets/markdown_styles.dart";

/// Displays AI reasoning/thinking content in a compact card.
///
/// While streaming, shows a faded preview of the last few lines. When
/// complete, collapses to a header-only card. Tapping opens a 70% modal
/// bottom sheet with the full text.
class ReasoningPartWidget extends StatefulWidget {
  final String text;
  final bool isStreaming;

  const ReasoningPartWidget({
    super.key,
    required this.text,
    this.isStreaming = false,
  });

  @override
  State<ReasoningPartWidget> createState() => _ReasoningPartWidgetState();
}

class _ReasoningPartWidgetState extends State<ReasoningPartWidget> {
  /// Carries the latest text and streaming flag so the modal bottom sheet
  /// can read data directly from the notifier instead of relying on
  /// [widget.text] which may become stale when the widget tree reorders
  /// parts during streaming.
  final _sheetState = ValueNotifier<({String text, bool isStreaming})>(
    (text: "", isStreaming: false),
  );

  @override
  void initState() {
    super.initState();
    _sheetState.value = (text: widget.text, isStreaming: widget.isStreaming);
  }

  @override
  void didUpdateWidget(ReasoningPartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sheetState.value = (text: widget.text, isStreaming: widget.isStreaming);
  }

  @override
  void dispose() {
    _sheetState.dispose();
    super.dispose();
  }

  void _showFullText() {
    final scrollController = ScrollController();
    var following = true;
    var sheetOpen = true;

    showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ValueListenableBuilder<({String text, bool isStreaming})>(
        valueListenable: _sheetState,
        builder: (_, data, __) => StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final theme = Theme.of(sheetContext);
            final loc = sheetContext.loc;
            final height = MediaQuery.of(sheetContext).size.height * 0.7;
            final text = data.text;
            final isStreaming = data.isStreaming;

            if (following && isStreaming) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!sheetOpen || !scrollController.hasClients) return;
                scrollController.animateTo(
                  scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                );
              });
            }

            return Container(
              height: height,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
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
                          isStreaming ? loc.sessionDetailThinking : loc.sessionDetailThought,
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
                            if (notification is ScrollUpdateNotification &&
                                notification.dragDetails != null &&
                                following) {
                              final pos = scrollController.position;
                              if (pos.pixels < pos.maxScrollExtent - 20) {
                                following = false;
                                setSheetState(() {});
                              }
                            }
                            return false;
                          },
                          child: ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            children: [
                              MarkdownBody(
                                data: text,
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
                        if (!following && isStreaming)
                          Positioned(
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
                                    following = true;
                                    setSheetState(() {});
                                    if (scrollController.hasClients) {
                                      scrollController.animateTo(
                                        scrollController.position.maxScrollExtent,
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
                                          loc.sessionDetailFollowOutput,
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
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ).whenComplete(() {
      sheetOpen = false;
      scrollController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.text.isEmpty && !widget.isStreaming) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final loc = context.loc;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        behavior: .opaque,
        onTap: _showFullText,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: .start,
            mainAxisSize: .min,
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
                        widget.isStreaming ? loc.sessionDetailThinking : loc.sessionDetailThought,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontStyle: .italic,
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
              if (widget.isStreaming && widget.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 10),
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.white],
                      stops: [0.0, 0.35],
                    ).createShader(bounds),
                    blendMode: .dstIn,
                    child: Container(
                      height: 56,
                      width: double.infinity,
                      clipBehavior: .hardEdge,
                      decoration: const BoxDecoration(),
                      child: OverflowBox(
                        alignment: Alignment.bottomLeft,
                        maxHeight: double.infinity,
                        child: Text(
                          widget.text,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
