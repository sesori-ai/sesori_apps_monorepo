part of "../project_list_screen.dart";

// ===========================================================================
// "Why is this needed?" info sheet
//
// The onboarding "Why is this needed?" button opens this as a PregoBottomSheet.
// It explains why the Bridge sits between the phone and the developer's machine:
// a lede paragraph, the connection graphic, three reassurance rows, and an FAQ.
// ===========================================================================

/// Content of the onboarding "Why is this needed?" bottom sheet. Pure
/// presentation with only per-row FAQ expand/collapse state; opened via
/// [showPregoBottomSheet] from [_OnboardingChecklist].
class _WhyBridgeInfoSheet extends StatelessWidget {
  const _WhyBridgeInfoSheet();

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;
    final loc = context.loc;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: PregoSpacing.md),
        // Lede: first line reads as the headline (primary), the rest as
        // supporting context (secondary), centred under the title.
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: loc.projectsOnboardingWhyLede,
                style: prego.textTheme.textMd.regular.copyWith(color: colors.textPrimary),
              ),
              const TextSpan(text: "\n"),
              TextSpan(
                text: loc.projectsOnboardingWhyBody,
                style: prego.textTheme.textSm.regular.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PregoSpacing.x2l),
        // Decorative illustration: a phone and desktop editor joined by an
        // "E2E Encrypted" badge, conveying that the bridge relays over an
        // end-to-end-encrypted channel. Exported from Figma at 1× = display
        // size, with @2×/@3× density variants.
        Center(
          child: ExcludeSemantics(
            child: Image.asset(
              "assets/images/projects_onboarding/info_graphic/why-needed.png",
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
        const SizedBox(height: PregoSpacing.x2l),
        _WhyFeatureRow(
          icon: TablerRegular.lock,
          title: loc.projectsOnboardingWhySecureTitle,
          subtitle: loc.projectsOnboardingWhySecureSubtitle,
        ),
        const PregoDivider(indent: PregoSpacing.x5l),
        _WhyFeatureRow(
          icon: TablerRegular.world,
          title: loc.projectsOnboardingWhyAnywhereTitle,
          subtitle: loc.projectsOnboardingWhyAnywhereSubtitle,
        ),
        const PregoDivider(indent: PregoSpacing.x5l),
        _WhyFeatureRow(
          icon: TablerRegular.bell,
          title: loc.projectsOnboardingWhyNotifiedTitle,
          subtitle: loc.projectsOnboardingWhyNotifiedSubtitle,
        ),
        const SizedBox(height: PregoSpacing.x3l),
        Text(
          loc.projectsOnboardingWhyFaqHeader,
          style: prego.textTheme.textMd.medium.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: PregoSpacing.xs),
        _WhyFaqItem(
          question: loc.projectsOnboardingWhyFaqDirectQuestion,
          answer: loc.projectsOnboardingWhyFaqDirectAnswer,
        ),
        const PregoDivider(indent: PregoSpacing.xl),
        _WhyFaqItem(
          question: loc.projectsOnboardingWhyFaqPcOnQuestion,
          answer: loc.projectsOnboardingWhyFaqPcOnAnswer,
        ),
        const PregoDivider(indent: PregoSpacing.xl),
        _WhyFaqItem(
          question: loc.projectsOnboardingWhyFaqReadQuestion,
          answer: loc.projectsOnboardingWhyFaqReadAnswer,
        ),
        const SizedBox(height: PregoSpacing.md),
      ],
    );
  }
}

/// One reassurance row: a leading icon and a title + subtitle. Merged into a
/// single semantics node so the icon, title, and subtitle are read as one unit.
class _WhyFeatureRow extends StatelessWidget {
  const _WhyFeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;

    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: PregoSpacing.lg,
          horizontal: PregoSpacing.xl,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: colors.textPrimary),
            const SizedBox(width: PregoSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: prego.textTheme.textMd.regular.copyWith(color: colors.textPrimary),
                  ),
                  const SizedBox(height: PregoSpacing.xxs),
                  Text(
                    subtitle,
                    style: prego.textTheme.textXs.regular.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single expandable FAQ row: a tappable question with a chevron that rotates
/// as its answer expands. Announces its expanded/collapsed state to screen
/// readers; wrapped in a [RepaintBoundary] so the expand animation (which sits
/// behind the sheet's glass header) doesn't repaint the whole column.
class _WhyFaqItem extends StatefulWidget {
  const _WhyFaqItem({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  State<_WhyFaqItem> createState() => _WhyFaqItemState();
}

class _WhyFaqItemState extends State<_WhyFaqItem> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            // Transparent Material so the InkWell ripple paints on top of the
            // sheet surface instead of behind it on the modal's transparent
            // Material — same pattern as the onboarding install boxes.
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: _toggle,
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    vertical: PregoSpacing.lg,
                    horizontal: PregoSpacing.xl,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.question,
                          style: prego.textTheme.textMd.regular.copyWith(color: colors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: PregoSpacing.md),
                      AnimatedRotation(
                        // Chevron points down when collapsed, up when expanded.
                        turns: _expanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(TablerRegular.chevron_down, size: 20, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            alignment: Alignment.topCenter,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsetsDirectional.only(
                      bottom: PregoSpacing.lg,
                      start: PregoSpacing.xl,
                      end: PregoSpacing.xl,
                    ),
                    child: Text(
                      widget.answer,
                      style: prego.textTheme.textXs.regular.copyWith(color: colors.textSecondary),
                    ),
                  )
                // Collapsed placeholder keeps full width so AnimatedSize only
                // animates height; a 0x0 child would sweep the width open too
                // if the parent ever stopped stretching its children.
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
