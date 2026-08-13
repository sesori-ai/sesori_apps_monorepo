import "dart:async";

import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

/// Dismisses the current modal route when its request is no longer pending.
class const PendingRequestAutoDismiss({
  super.key,
  required final Stream<bool> isPendingStream,
  required final bool Function() isPending,
  required final Widget child,
}) extends StatefulWidget {
  @override
  State<PendingRequestAutoDismiss> createState() => _PendingRequestAutoDismissState();
}

class _PendingRequestAutoDismissState() extends State<PendingRequestAutoDismiss> {
  late final StreamSubscription<bool> _subscription;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget.isPendingStream.listen(_dismissIfResolved);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _dismissIfResolved(widget.isPending());
    });
  }

  void _dismissIfResolved(bool isPending) {
    if (isPending || _resolved || !mounted || ModalRoute.of(context)?.isCurrent != true) return;
    setState(() => _resolved = true);
    context.pop();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AbsorbPointer(absorbing: _resolved, child: widget.child);
}
