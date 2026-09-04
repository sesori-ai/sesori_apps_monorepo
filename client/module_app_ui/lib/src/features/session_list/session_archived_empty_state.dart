import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";

/// Empty state for the sessions list while the archived filter is on and the
/// project has nothing archived.
///
/// Product shells may inject their own [artwork]. The shared package owns the
/// layout and localized label but never names a product asset.
class const SessionArchivedEmptyState({
  super.key,
  required final Widget? artwork,
}) extends StatelessWidget {
  /// Gap between the optional illustration and the label.
  static const double _labelGap = 33;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final artwork = this.artwork;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (artwork != null) ...[
            ExcludeSemantics(
              key: const Key("session-empty-archive"),
              child: artwork,
            ),
            const SizedBox(height: _labelGap),
          ],
          Text(
            context.loc.sessionListEmptyArchived,
            textAlign: TextAlign.center,
            style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
