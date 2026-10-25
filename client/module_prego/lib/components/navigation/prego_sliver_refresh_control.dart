import "dart:async";

import "package:cupertino_ui/cupertino_ui.dart" show CupertinoSliverRefreshControl, RefreshIndicatorMode;
import "package:material_ui/material_ui.dart";

/// The pull-to-refresh control every Prego surface uses.
///
/// Wraps [CupertinoSliverRefreshControl], which arms its task the moment the
/// pull crosses the trigger while the finger is still down. This dispatches the
/// host's callback only once the pull is let go, so whatever the refresh shows
/// at the top of the list arrives after the finger lifts rather than under it.
///
/// Hosts differ in where the indicator sits, not in how the pull behaves, so
/// they supply [decorate] and get identical gesture semantics for free — which
/// is why this exists rather than a parameter on one scaffold.
class const PregoSliverRefreshControl({
  super.key,
  required final Future<void> Function() _onRefresh,

  /// Wraps the built indicator so a host can position it without owning any
  /// gesture logic. `null` paints it where the control puts it.
  required final Widget Function(BuildContext context, Widget indicator)? _decorate,

  /// Reports the space the control currently holds open, for hosts that lay
  /// out against it. Zero whenever the control is inactive.
  required final void Function(double extent)? _onPulledExtentChanged,
}) extends StatefulWidget {
  @override
  State<PregoSliverRefreshControl> createState() => _PregoSliverRefreshControlState();
}

class _PregoSliverRefreshControlState() extends State<PregoSliverRefreshControl> {
  /// Completes once the pull is let go. `null` whenever no refresh is pending.
  Completer<void>? _letGo;

  Future<void> _runRefresh() async {
    final letGo = Completer<void>();
    _letGo = letGo;
    try {
      await letGo.future;
      await widget._onRefresh();
    } finally {
      if (identical(_letGo, letGo)) _letGo = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoSliverRefreshControl(
      onRefresh: _runRefresh,
      builder: (context, refreshState, pulledExtent, triggerDistance, indicatorExtent) {
        widget._onPulledExtentChanged?.call(
          refreshState == RefreshIndicatorMode.inactive ? 0 : pulledExtent,
        );
        // Anything past `armed` means the finger is off: the underlying control
        // only leaves `armed` once the extent has fallen back to the height it
        // holds on its own.
        if (refreshState != RefreshIndicatorMode.drag && refreshState != RefreshIndicatorMode.armed) {
          if (_letGo case final letGo? when !letGo.isCompleted) letGo.complete();
        }
        final indicator = CupertinoSliverRefreshControl.buildRefreshIndicator(
          context,
          refreshState,
          pulledExtent,
          triggerDistance,
          indicatorExtent,
        );
        return widget._decorate?.call(context, indicator) ?? indicator;
      },
    );
  }
}
