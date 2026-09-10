import "dart:async";

import "package:flutter/widgets.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Owns visibility and activity analytics for the inherited [SessionDetailCubit].
///
/// The shell constructs and owns the cubit above this widget. The top route
/// identifies the detail kind; the nearest page distinguishes retained details
/// when another detail of the same kind is pushed in the nested navigator.
class const SessionDetailActivityOwner({
  super.key,
  required final RouteSource routeSource,
  required final LifecycleSource lifecycleSource,
  required final ProductAnalyticsService productAnalyticsService,
  required final AppRouteDef expectedDetailRoute,
  required final Widget child,
}) extends StatefulWidget {
  @override
  State<SessionDetailActivityOwner> createState() => _SessionDetailActivityOwnerState();
}

class _SessionDetailActivityOwnerState() extends State<SessionDetailActivityOwner> {
  SessionActivityAnalyticsListener? _listener;
  StreamSubscription<AppRouteDef?>? _routeSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeSubscription ??= widget.routeSource.currentRouteStream.listen((_) => _updateRouteVisibility());
    _updateRouteVisibility();
  }

  void _updateRouteVisibility() {
    final isPageCurrent = ModalRoute.of(context)?.isCurrent ?? false;
    final isRouteVisible = widget.routeSource.currentRoute == widget.expectedDetailRoute && isPageCurrent;
    final cubit = context.read<SessionDetailCubit>();
    cubit.setRouteVisible(isVisible: isRouteVisible);
    final listener = _listener;
    if (listener == null) {
      _listener = SessionActivityAnalyticsListener(
        sessionDetailCubit: cubit,
        lifecycleSource: widget.lifecycleSource,
        productAnalyticsService: widget.productAnalyticsService,
        initialRouteVisible: isRouteVisible,
      );
    } else {
      listener.setRouteVisible(isVisible: isRouteVisible);
    }
  }

  @override
  void dispose() {
    final listener = _listener;
    if (listener != null) unawaited(listener.dispose());
    unawaited(_routeSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
