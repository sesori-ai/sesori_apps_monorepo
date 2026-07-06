import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";
import "../../../core/widgets/markdown_styles.dart";
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

  /// Opens the reasoning modal as a bottom sheet, forwarding the presenting
  /// context's [SessionDetailCubit] into the sheet's own route.
  ///
  /// Presents a [PregoBottomSheet] directly (not via [showPregoBottomSheet])
  /// because the sheet title tracks the live streaming state.
  static Future<void> show(
    BuildContext context, {
    required String partId,
    required String messageId,
  }) {
    final cubit = context.read<SessionDetailCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // PregoBottomSheet paints the rounded surface; keep the route
      // transparent. The sheet caps itself below the status bar.
      backgroundColor: Colors.transparent,
      useSafeArea: false,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: ReasoningModal(partId: partId, messageId: messageId),
      ),
    );
  }

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

    final prego = context.prego;
    final loc = context.loc;
    final height = MediaQuery.sizeOf(context).height * 0.7;

    // Coalesced post-frame tail-jump. Safe to call every rebuild;
    // repeated calls within a frame collapse into one jump. Gated on
    // isStreaming so a settled modal does not re-pin when the user
    // has scrolled into historical reasoning.
    if (data.isStreaming) {
      _follow.scheduleJumpToEdge();
    }

    return PregoBottomSheet(
      title: data.isStreaming ? loc.sessionDetailThinking : loc.sessionDetailThought,
      // The modal route strips the top padding from the sheet's MediaQuery;
      // viewPadding survives, so read the status-bar inset from it.
      topInset: MediaQuery.viewPaddingOf(context).top,
      onClose: () => context.pop(),
      // Full-bleed body; the list pads itself.
      contentPadding: EdgeInsetsDirectional.zero,
      child: SizedBox(
        // The body hosts its own scroll view (the follow/detach list needs to
        // own scrolling), so it gets a bounded height.
        height: height,
        child: FollowDetachScrollable(
          tracker: _follow,
          detachedOverlayBuilder: data.isStreaming
              ? (ctx) => JumpToEdgePill(
                  tapTargetKey: _kFollowOutputKey,
                  label: loc.sessionDetailFollowOutput,
                  onTap: () => _follow.animateToEdge(),
                  // No floating composer in the reasoning sheet.
                  bottomInset: 0,
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
                    prego: prego,
                    paragraphStyle: prego.textTheme.textXs.regular.copyWith(
                      color: prego.colors.textSecondary,
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
