part of "bridge_onboarding.dart";

void switchComputer({required String bridgeId, required ComputerSwitchSource source}) =>
    unawaited(getIt<ComputerSwitchDispatcher>().switchTo(bridgeId: bridgeId, source: source));

/// Opens the Computers page from a computer menu. Settings goes under it so
/// Back from Computers lands there.
void manageComputers({required BuildContext context}) {
  context.pushRoute(const AppRoute.settings());
  context.pushRoute(const AppRoute.settingsComputers());
}

/// The page for a computer that is not connected, on the home and in
/// Archived: setup onboarding before any bridge is registered, otherwise the
/// offline flow. "Need help?" closes it in the space left below: pinned to the
/// bottom while the body is shorter than the viewport, and right after it once
/// the body grows taller, so it never covers the body.
class const DisconnectedComputerSlivers({super.key, required final ProjectListBridgeDisconnected state})
    extends StatefulWidget {
  @override
  State<DisconnectedComputerSlivers> createState() => _DisconnectedComputerSliversState();
}

class _DisconnectedComputerSliversState() extends State<DisconnectedComputerSlivers> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    // Keeps the offline computer's last-seen time current.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final bridge = switch (context.watch<BridgeIdentityCubit>().state) {
      BridgeIdentityNamed(:final bridge) => bridge,
      BridgeIdentityPending() || BridgeIdentityUnnamed() => null,
    };
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: state.hasRegisteredBridges
              ? BridgeOfflineView(bridge: bridge, onSwitchComputer: switchComputer)
              : const ConnectBridgeChecklist(),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(vertical: PregoSpacing.xl),
                child: NeedHelpMenu(
                  surface: state.hasRegisteredBridges
                      ? OnboardingSurface.bridgeOffline
                      : OnboardingSurface.connectSetup,
                  // The offline fix is the command above, so help stays a quiet link.
                  quiet: state.hasRegisteredBridges,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
