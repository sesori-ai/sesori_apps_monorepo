part of "../project_list_screen.dart";

/// Shown when the bridge is connected but the project list is empty
/// ("Your bridge is connected"). Renders the shared onboarding checklist in
/// its connected state: steps 1 & 2 ticked and a live Step 3 folder button.
///
/// Scrolls (and so cooperates with the enclosing pull-to-refresh) even though
/// the content is short, via [AlwaysScrollableScrollPhysics].
class _ConnectedEmptyView extends StatelessWidget {
  const _ConnectedEmptyView({required this.onAddProject});

  final VoidCallback onAddProject;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        clipBehavior: Clip.none,
        physics: const AlwaysScrollableScrollPhysics(),
        child: _OnboardingChecklist(connected: true, onOpenFolder: onAddProject),
      ),
    );
  }
}
