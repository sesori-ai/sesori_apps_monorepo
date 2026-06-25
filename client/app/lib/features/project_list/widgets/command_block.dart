part of "../project_list_screen.dart";

/// The shared install-command block: platform tabs (Linux/Mac vs Windows), a
/// copy button, and the monospace install + run command lines.
///
/// Self-contained — it owns the selected-platform state and the copy-to-
/// clipboard behaviour — so both the onboarding checklist and the bridge
/// "reconnect" screen drop it in with no wiring (`const _CommandBlock()`).
class _CommandBlock extends StatefulWidget {
  const _CommandBlock();

  @override
  State<_CommandBlock> createState() => _CommandBlockState();
}

class _CommandBlockState extends State<_CommandBlock> {
  /// Selected install platform tab. `false` = Linux/Mac (default), `true` = Windows.
  bool _isWindows = false;

  String get _installCommand => _isWindows ? BridgeInstall.windowsCommand : BridgeInstall.macLinuxCommand;

  Future<void> _copyCommand() async {
    final messenger = ScaffoldMessenger.of(context);
    final loc = context.loc;
    // Clipboard can throw on restricted platforms/states; fail soft and skip
    // the success snackbar, matching CopyIconButton.
    try {
      await Clipboard.setData(ClipboardData(text: _installCommand));
    } on Object catch (_) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(loc.projectsOnboardingCommandCopied),
        duration: kSnackBarDuration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;
    final loc = context.loc;
    final mono = prego.textTheme.textXs.regular.copyWith(color: colors.textSecondary).monospace;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.md, vertical: PregoSpacing.lg),
      decoration: BoxDecoration(
        color: colors.bgSecondaryAlt,
        borderRadius: BorderRadius.circular(PregoRadius.lg),
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
                    selected: !_isWindows,
                    onTap: () => setState(() => _isWindows = false),
                  ),
                  const SizedBox(width: PregoSpacing.sm),
                  _PlatformTab(
                    label: loc.projectsOnboardingTabWindows,
                    selected: _isWindows,
                    onTap: () => setState(() => _isWindows = true),
                  ),
                ],
              ),
              Semantics(
                button: true,
                label: loc.projectsOnboardingCopyCommand,
                child: InkResponse(
                  onTap: _copyCommand,
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
          const SizedBox(height: PregoSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.lg, vertical: PregoSpacing.sm),
            // semanticsLabel carries the full command so screen readers read it
            // even though the visible text is clamped to one line with ellipsis.
            child: Text(
              _installCommand,
              semanticsLabel: _installCommand,
              style: mono,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.lg, vertical: PregoSpacing.sm),
            child: Text(
              BridgeInstall.runCommand,
              semanticsLabel: BridgeInstall.runCommand,
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
    return Icon(TablerRegular.copy, size: 16, color: context.prego.colors.textTertiary);
  }
}

class _PlatformTab extends StatelessWidget {
  const _PlatformTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;

    // selected: exposes the active platform to assistive tech (the InkWell
    // already conveys the tappable/label semantics; only selection is missing).
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PregoRadius.xxs),
        child: Container(
          height: 28,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.lg),
          decoration: BoxDecoration(
            color: selected ? colors.buttonGlassPrimaryBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(PregoRadius.xxs),
          ),
          child: Text(
            label,
            style: prego.textTheme.textSm.medium.copyWith(
              color: selected ? colors.textPrimary : colors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
