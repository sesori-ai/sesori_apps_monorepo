import "dart:async";

import "package:cue/cue.dart";
import "package:flutter/material.dart";

/// A full-screen loading overlay shown while a new session is being created.
///
/// Fills its parent and visually dims underlying content. Displays a centered
/// card with a progress indicator and a cycling playful message.
///
/// Uses [Cue] entrance animation when motion is not disabled by accessibility
/// settings. Safe to place inside a [Stack] with [Positioned.fill].
class NewSessionLoadingOverlay extends StatefulWidget {
  const NewSessionLoadingOverlay({
    super.key = const Key("new_session_loading_overlay"),
    required this.semanticsLabel,
    required this.messages,
  });

  final String semanticsLabel;
  final List<String> messages;

  @override
  State<NewSessionLoadingOverlay> createState() => _NewSessionLoadingOverlayState();
}

class _NewSessionLoadingOverlayState extends State<NewSessionLoadingOverlay> {
  int _messageIndex = 0;
  Timer? _timer;

  bool get _isReducedMotion {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final accessibleNav = MediaQuery.maybeAccessibleNavigationOf(context) ?? false;
    return disableAnimations || accessibleNav;
  }

  void _startTimer() {
    if (_timer?.isActive ?? false) return;
    _timer = Timer.periodic(const Duration(seconds: 3, milliseconds: 500), (_) {
      if (mounted) {
        setState(() => _messageIndex = (_messageIndex + 1) % widget.messages.length);
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isReducedMotion) {
      _stopTimer();
    } else {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = _isReducedMotion;

    return SizedBox.expand(
      child: Semantics(
        label: widget.semanticsLabel,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.scrim.withAlpha(160),
          child: Center(
            child: reducedMotion
                ? _buildContent(context, reducedMotion: true)
                : Cue.onMount(
                    motion: const CueMotion.smooth(),
                    child: Actor(
                      acts: const [
                        Act.fadeIn(),
                        Act.scale(from: 0.9),
                        Act.slideY(from: 0.2),
                      ],
                      child: _buildContent(context, reducedMotion: false),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, {required bool reducedMotion}) {
    final theme = Theme.of(context);
    final message = widget.messages[_messageIndex];

    return Card(
      elevation: 8,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                key: const Key("new_session_loading_progress"),
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              reducedMotion
                  ? Text(
                      message,
                      key: const Key("new_session_loading_message"),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.4),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        message,
                        key: ValueKey<String>(message),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
