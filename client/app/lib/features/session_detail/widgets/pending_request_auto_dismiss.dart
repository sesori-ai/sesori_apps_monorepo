import "dart:async";

import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

/// Dismisses the current modal route when its request is no longer pending.
class PendingRequestAutoDismiss extends StatefulWidget {
  final Stream<bool> isPendingStream;
  final Widget child;

  const PendingRequestAutoDismiss({
    super.key,
    required this.isPendingStream,
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
    _subscription = widget.isPendingStream.listen((isPending) {
      if (isPending || !mounted || ModalRoute.of(context)?.isCurrent != true) return;
      context.pop();
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
