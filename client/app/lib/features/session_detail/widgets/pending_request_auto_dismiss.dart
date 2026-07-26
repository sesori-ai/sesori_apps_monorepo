import "dart:async";

import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

/// Dismisses the current modal route when its request is no longer pending.
class PendingRequestAutoDismiss extends StatefulWidget {
  final Stream<bool> isPendingStream;
  final bool Function() isPending;
  final Widget child;

  const PendingRequestAutoDismiss({
    super.key,
    required this.isPendingStream,
    required this.isPending,
    required this.child,
  });

  @override
  State<PendingRequestAutoDismiss> createState() => _PendingRequestAutoDismissState();
}

class _PendingRequestAutoDismissState extends State<PendingRequestAutoDismiss> {
  late final StreamSubscription<bool> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.isPendingStream.listen(_dismissIfResolved);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _dismissIfResolved(widget.isPending());
    });
  }

  void _dismissIfResolved(bool isPending) {
    if (isPending || !mounted || ModalRoute.of(context)?.isCurrent != true) return;
    context.pop();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
