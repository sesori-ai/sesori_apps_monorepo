import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../../core/extensions/build_context_x.dart";
import "assistant_message_card.dart";
import "user_message_card.dart";

class SessionDetailMessageList extends StatefulWidget {
  final String? projectId;
  final List<MessageWithParts> messages;
  final Map<String, String> streamingText;
  final List<Session> children;
  final Map<String, SessionStatus> childStatuses;

  const SessionDetailMessageList({
    super.key,
    required this.projectId,
    required this.messages,
    required this.streamingText,
    required this.children,
    required this.childStatuses,
  });

  @override
  State<SessionDetailMessageList> createState() => _SessionDetailMessageListState();
}

class _SessionDetailMessageListState extends State<SessionDetailMessageList> {
  static const _kNearBottomThreshold = 20.0;
  static const _kListViewKey = Key("session-detail-message-list-view");
  static const _kJumpToLatestKey = Key("session-detail-jump-to-latest");

  late final ScrollController _scrollController;
  bool _following = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SessionDetailMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_scrollController.hasClients) return;

    final oldPixels = _scrollController.position.pixels;
    final oldMaxScrollExtent = _scrollController.position.maxScrollExtent;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      if (_following) {
        _scrollController.jumpTo(0);
        return;
      }

      final position = _scrollController.position;
      final delta = position.maxScrollExtent - oldMaxScrollExtent;
      final target = (oldPixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent);
      _scrollController.jumpTo(target.toDouble());
    });
  }

  void _jumpToLatest() {
    setState(() => _following = true);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification) {
              // Desktop wheel/trackpad scrolling can update pixels without drag details.
              _updateFollowingFromPixels();
            } else if (notification is ScrollEndNotification) {
              _updateFollowingFromPixels();
            }
            return false;
          },
          child: ListView.builder(
            key: _kListViewKey,
            controller: _scrollController,
            reverse: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: widget.messages.length,
            itemBuilder: (context, index) {
              final message = widget.messages[widget.messages.length - 1 - index];
              final child = message.info.role == "user"
                  ? UserMessageCard(message: message)
                  : AssistantMessageCard(
                      projectId: widget.projectId,
                      message: message,
                      streamingText: widget.streamingText,
                      children: widget.children,
                      childStatuses: widget.childStatuses,
                    );
              return KeyedSubtree(key: ValueKey(message.info.id), child: child);
            },
          ),
        ),
        if (!_following)
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
                  key: _kJumpToLatestKey,
                  borderRadius: BorderRadius.circular(20),
                  onTap: _jumpToLatest,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_downward, size: 16, color: theme.colorScheme.onPrimaryContainer),
                        const SizedBox(width: 6),
                        Text(
                          loc.sessionDetailJumpToLatest,
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
    );
  }

  void _updateFollowingFromPixels() {
    if (!_scrollController.hasClients) return;

    final pixels = _scrollController.position.pixels;
    final shouldFollow = pixels <= _kNearBottomThreshold;
    if (_following != shouldFollow) {
      setState(() => _following = shouldFollow);
    }
  }
}
