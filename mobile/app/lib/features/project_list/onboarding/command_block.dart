part of "../project_list_screen.dart";

/// The Step 1 install-command block: platform tabs, copy button, and the
/// monospace command lines.
class _CommandBlock extends StatelessWidget {
  const _CommandBlock({
    required this.installCommand,
    required this.runCommand,
    required this.isWindows,
    required this.onSelectUnix,
    required this.onSelectWindows,
    required this.onCopy,
  });

  final String installCommand;
  final String runCommand;
  final bool isWindows;
  final VoidCallback onSelectUnix;
  final VoidCallback onSelectWindows;
  final Future<void> Function() onCopy;

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;
    final colors = zyra.colors;
    final loc = context.loc;
    final mono = zyra.textTheme.textXs.regular.copyWith(
      fontFamily: "monospace",
      fontFamilyFallback: const ["Menlo", "Roboto Mono", "Courier New"],
      color: colors.textSecondary,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: ZyraSpacing.md, vertical: ZyraSpacing.lg),
      decoration: BoxDecoration(
        color: colors.bgSecondaryAlt,
        borderRadius: BorderRadius.circular(ZyraRadius.lg),
        border: Border.all(color: colors.borderSecondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PlatformTab(
                    label: loc.projectsOnboardingTabUnix,
                    selected: !isWindows,
                    onTap: onSelectUnix,
                  ),
                  const SizedBox(width: ZyraSpacing.sm),
                  _PlatformTab(
                    label: loc.projectsOnboardingTabWindows,
                    selected: isWindows,
                    onTap: onSelectWindows,
                  ),
                ],
              ),
              Semantics(
                button: true,
                label: loc.projectsOnboardingCopyCommand,
                child: InkResponse(
                  onTap: onCopy,
                  radius: 22,
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(child: _CopyIcon()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZyraSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZyraSpacing.lg, vertical: ZyraSpacing.sm),
            // semanticsLabel carries the full command so screen readers read it
            // even though the visible text is clamped to one line with ellipsis.
            child: Text(
              installCommand,
              semanticsLabel: installCommand,
              style: mono,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZyraSpacing.lg, vertical: ZyraSpacing.sm),
            child: Text(
              runCommand,
              semanticsLabel: runCommand,
              style: mono,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyIcon extends StatelessWidget {
  const _CopyIcon();

  @override
  Widget build(BuildContext context) {
    return Icon(TablerOutline.copy, size: 16, color: context.zyra.colors.textTertiary);
  }
}

class _PlatformTab extends StatelessWidget {
  const _PlatformTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;
    final colors = zyra.colors;

    // selected: exposes the active platform to assistive tech (the InkWell
    // already conveys the tappable/label semantics; only selection is missing).
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZyraRadius.xxs),
        child: Container(
          height: 28,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: ZyraSpacing.lg),
          decoration: BoxDecoration(
            color: selected ? colors.buttonGlassPrimaryBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(ZyraRadius.xxs),
          ),
          child: Text(
            label,
            style: zyra.textTheme.textSm.medium.copyWith(
              color: selected ? colors.textPrimary : colors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
