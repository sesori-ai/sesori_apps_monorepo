import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_zyra/module_zyra.dart";

import "../../../core/extensions/build_context_x.dart";
import "../../../core/widgets/markdown_styles.dart";
import "../../../l10n/app_localizations.dart";
import "follow_detach_scrollable.dart";
import "jump_to_edge_pill.dart";
import "scroll_follow_tracker.dart";

/// Modal body for displaying AI reasoning/thinking content.
///
/// Self-subscribes to [SessionDetailCubit] via [context.select] for
/// real-time streaming updates — replaces the stale ValueNotifier
/// pattern.
///
/// Scroll behaviour — "follow / detach":
///
/// - Uses a non-reversed `ListView`, so the latest streamed tokens
///   live at `maxScrollExtent`. While **following**, a single
///   coalesced post-frame `jumpTo(maxScrollExtent)` is scheduled per
///   rebuild (via [ScrollFollowTracker.scheduleJumpToEdge]) so
///   fast streaming updates never stack overlapping animations.
/// - Detach triggers (drag start, trackpad scroll, trackpad pan) are
///   wired through [FollowDetachScrollable]. While detached, live
///   updates keep arriving but the scroll position is left alone.
/// - The "Follow" button tap performs one explicit animated scroll to
///   the tail via [ScrollFollowTracker.animateToEdge].
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
  static const _kListViewKey = Key("reasoning-modal-list-view");
  static const _kFollowOutputKey = Key("reasoning-modal-follow-output");

  late final ScrollFollowTracker _follow;

  @override
  void initState() {
    super.initState();
    _follow = ScrollFollowTracker(edge: ScrollFollowEdge.max);
  }

  @override
  void dispose() {
    _follow.dispose();
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

    final zyra = context.zyra;
    final loc = context.loc;
    final height = MediaQuery.of(context).size.height * 0.7;

    // Coalesced post-frame tail-jump. Safe to call every rebuild;
    // repeated calls within a frame collapse into one jump. Gated on
    // isStreaming so a settled modal does not re-pin when the user
    // has scrolled into historical reasoning.
    if (data.isStreaming) {
      _follow.scheduleJumpToEdge();
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: zyra.colors.bgPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          _buildDragHandle(zyra: zyra),
          _buildHeader(zyra: zyra, isStreaming: data.isStreaming, loc: loc),
          const Divider(height: 1),
          Expanded(
            child: FollowDetachScrollable(
              tracker: _follow,
              detachedOverlayBuilder: data.isStreaming
                  ? (ctx) => JumpToEdgePill(
                        tapTargetKey: _kFollowOutputKey,
                        label: loc.sessionDetailFollowOutput,
                        onTap: () => _follow.animateToEdge(),
                      )
                  : null,
              child: ListView(
                key: _kListViewKey,
                controller: _follow.scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  SelectionArea(
                    child: MarkdownBody(
                      data: data.text,
                      selectable: false,
                      onTapLink: handleMarkdownLinkTap,
                      styleSheet: buildSessionMarkdownStyleSheet(
                        zyra: zyra,
                        paragraphStyle: zyra.textTheme.textXs.regular.copyWith(
                          color: zyra.colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDragHandle({required ZyraDesignSystem zyra}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: zyra.colors.borderSecondary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader({
    required ZyraDesignSystem zyra,
    required bool isStreaming,
    required AppLocalizations loc,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 12),
      child: Row(
        children: [
          Icon(Icons.psychology, size: 20, color: zyra.colors.borderPrimary),
          const SizedBox(width: 8),
          Text(
            isStreaming ? loc.sessionDetailThinking : loc.sessionDetailThought,
            style: zyra.textTheme.textMd.bold.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
