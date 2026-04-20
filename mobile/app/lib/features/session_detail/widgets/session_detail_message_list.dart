import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
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
  bool _userScrollActive = false;

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

      if (_userScrollActive) {
        return;
      }

      final position = _scrollController.position;
      final delta = position.maxScrollExtent - oldMaxScrollExtent;
      final target = (oldPixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent);
      _scrollController.jumpTo(target.toDouble());
    });
  }

  void _jumpToLatest() {
    setState(() {
      _following = true;
      _userScrollActive = false;
    });
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
        Listener(
          onPointerSignal: _handlePointerSignal,
          onPointerPanZoomStart: (_) => _detachForUserScroll(),
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.depth != 0) return false;

              if (_isUserScrollStart(notification)) {
                _detachForUserScroll();
              } else if (notification is ScrollEndNotification && _userScrollActive) {
                _settleUserScroll(shouldFollow: notification.metrics.pixels <= _kNearBottomThreshold);
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

  bool _isUserScrollStart(ScrollNotification notification) {
    return (notification is ScrollStartNotification && notification.dragDetails != null) ||
        (notification is UserScrollNotification && notification.direction != ScrollDirection.idle);
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      _detachForUserScroll();
    }
  }

  void _detachForUserScroll() {
    if (_userScrollActive && !_following) return;

    setState(() {
      _userScrollActive = true;
      _following = false;
    });
  }

  void _settleUserScroll({required bool shouldFollow}) {
    if (!_userScrollActive && _following == shouldFollow) return;

    setState(() {
      _userScrollActive = false;
      _following = shouldFollow;
    });
  }
}
