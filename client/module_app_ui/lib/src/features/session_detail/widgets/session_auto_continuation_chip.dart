import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../utils/auto_continuation_time.dart";
import "session_auto_continuation_notice.dart";

/// Quiet "Auto-continue" chip in the session's model row while
/// auto-continuation is enabled and nothing is due. Its menu offers Disable.
/// The card above the composer replaces it while a continuation is pending or
/// an attempt needs explaining (see [sessionAutoContinuationNoticeVisible]).
class const SessionAutoContinuationChip({
  super.key,
  required final PregoComposerSurfaceStyle surfaceStyle,
  required final SessionAutoContinuationView view,

  /// Touch rows show only the clock, which keeps the pickers readable.
  required final bool showLabel,
  required final bool updating,
  required final VoidCallback onDisable,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return PregoAnchorMenu(
      flat: true,
      acquireOpenLease: null,
      menuMaxHeight: null,
      triggerBuilder: (context, toggle) => PregoComposerChip(
        key: const Key("session-auto-continuation-chip"),
        icon: TablerRegular.clock,
        label: loc.sessionAutoContinuationChip,
        showLabel: showLabel,
        surfaceStyle: surfaceStyle,
        onPressed: toggle,
      ),
      entriesBuilder: () => [
        PregoMenuLabel(text: loc.sessionAutoContinuationOn),
        PregoMenuItem(
          key: const Key("session-auto-continuation-chip-disable"),
          title: loc.sessionAutoContinuationDisable,
          subtitle: _subtitle(context),
          isSelected: false,
          isEnabled: !updating,
          shortcutLabel: null,
          onTap: onDisable,
        ),
      ],
    );
  }

  String _subtitle(BuildContext context) {
    final loc = context.loc;
    if (view.status case SessionAutoContinuationSubmitted(:final acceptedAt)) {
      return loc.sessionAutoContinuationSubmitted(sessionAutoContinuationLocalTime(loc: loc, milliseconds: acceptedAt));
    }
    return view.availability == AutoContinuationAvailability.conditional
        ? loc.sessionAutoContinuationAfterQuotaResets
        : loc.sessionAutoContinuationUnavailable;
  }
}
