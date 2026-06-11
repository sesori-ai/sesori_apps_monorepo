part of "../project_list_screen.dart";

/// Shown when the account has a bridge registered but none is connected —
/// the user already went through setup, so instead of the install onboarding
/// they are asked to start the bridge on their computer.
///
// TODO: placeholder copy, hardcoded on purpose — localize it together with
// the proper copy once the real design for this state lands.
const _bridgeOfflinePlaceholderTitle = "Turn on your bridge";
const _bridgeOfflinePlaceholderDetail =
    "Sesori Bridge is set up but not running. Start it on your computer and your projects will appear here.";

/// Placeholder UI: the final design for this state doesn't exist yet, so this
/// renders a minimal hero + message. The pull-to-refresh mirrors the setup
/// onboarding's recovery affordance (re-attempts the bridge connection).
class _BridgeOfflineView extends StatelessWidget {
  const _BridgeOfflineView();

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;

    return SafeArea(
      top: false,
      child: RefreshIndicator(
        onRefresh: () => context.read<ProjectListCubit>().reconnectBridge(),
        child: SingleChildScrollView(
          clipBehavior: Clip.none,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: ZyraSpacing.md),
              const Center(
                child: ExcludeSemantics(child: _OnboardingHero.offline()),
              ),
              const SizedBox(height: ZyraSpacing.x2l),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: ZyraSpacing.xl),
                child: Text(
                  _bridgeOfflinePlaceholderTitle,
                  textAlign: TextAlign.center,
                  style: zyra.textTheme.displayXs.medium.copyWith(color: zyra.colors.textPrimary),
                ),
              ),
              const SizedBox(height: ZyraSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: ZyraSpacing.x2l),
                child: Text(
                  _bridgeOfflinePlaceholderDetail,
                  textAlign: TextAlign.center,
                  style: zyra.textTheme.textSm.regular.copyWith(color: zyra.colors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
