import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

/// Alarm-clock chip in the session's model row while agents have set wake-ups
/// for the session, saying when the next one fires. Its menu lists each
/// wake-up with its time and label, a repeat mark when it repeats and a
/// terminal mark when it runs a command, and offers Cancel on each.
class const SessionWakeUpChip({
  super.key,
  required final PregoComposerSurfaceStyle surfaceStyle,

  /// The session's wake-ups, soonest first.
  required final List<SessionWakeUp> wakeUps,

  /// Touch rows show only the glyph, which keeps the pickers readable.
  required final bool showLabel,
  required final ValueChanged<String> onCancel,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final label = switch (wakeUps) {
      [final next, ...] => loc.sessionWakeUpChip(context.formatMessageTimestamp(next.nextDueAt)),
      [] => loc.sessionWakeUpsTitle,
    };
    return PregoAnchorMenu(
      flat: true,
      menuWidth: 280,
      menuMaxHeight: null,
      triggerBuilder: (context, toggle) => PregoComposerChip(
        key: const Key("session-wake-up-chip"),
        icon: TablerRegular.alarm,
        label: label,
        showLabel: showLabel,
        isWarning: false,
        surfaceStyle: surfaceStyle,
        onPressed: toggle,
      ),
      entriesBuilder: () => [
        PregoMenuLabel(text: loc.sessionWakeUpsTitle),
        for (final wakeUp in wakeUps)
          PregoMenuCustom(
            // Only the glass menu reads the height; this one is flat.
            height: 0,
            builder: (context, close) => _WakeUpRow(
              wakeUp: wakeUp,
              onCancel: () {
                close();
                onCancel(wakeUp.id);
              },
            ),
          ),
      ],
    );
  }
}

/// One wake-up in the chip's menu: its repeat or alarm glyph, its label over
/// its time and command mark, and its Cancel button.
class const _WakeUpRow({required final SessionWakeUp wakeUp, required final VoidCallback onCancel})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final secondary = prego.colors.textSecondary;
    final time = context.formatMessageTimestamp(wakeUp.nextDueAt);
    final description = [
      wakeUp.label,
      time,
      if (wakeUp.repeats) loc.sessionWakeUpRepeats,
      if (wakeUp.runsCommand) loc.sessionWakeUpRunsCommand,
    ].join(", ");
    return Padding(
      key: Key("session-wake-up-${wakeUp.id}"),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 12, 8),
      child: Row(
        spacing: 12,
        children: [
          // The row's description already says it repeats.
          ExcludeSemantics(
            child: Icon(
              wakeUp.repeats ? TablerRegular.repeat : TablerRegular.alarm,
              key: Key(wakeUp.repeats ? "session-wake-up-repeat-mark" : "session-wake-up-once-mark"),
              size: 20,
              color: secondary,
            ),
          ),
          Expanded(
            child: Semantics(
              label: description,
              excludeSemantics: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wakeUp.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textPrimary),
                  ),
                  Row(
                    spacing: PregoSpacing.xs,
                    children: [
                      Flexible(
                        child: Text(
                          time,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: prego.textTheme.textXs.regular.copyWith(color: secondary),
                        ),
                      ),
                      if (wakeUp.runsCommand)
                        Icon(
                          TablerRegular.terminal_2,
                          key: const Key("session-wake-up-command-mark"),
                          size: PregoIconSize.sm,
                          color: secondary,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Read right after the wake-up it cancels.
          PregoButtonsSolid(
            key: Key("session-wake-up-cancel-${wakeUp.id}"),
            label: loc.sessionWakeUpCancel,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.xs,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
