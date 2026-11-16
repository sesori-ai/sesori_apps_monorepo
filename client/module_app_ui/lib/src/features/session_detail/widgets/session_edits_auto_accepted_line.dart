import "package:material_ui/material_ui.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

/// The quiet line above the composer while the session's file edits run
/// without asking, with the way to make the next edit ask again.
class const SessionEditsAutoAcceptedLine({
  super.key,
  required final VoidCallback? onTurnOff,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: PregoSpacing.xs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                "${loc.sessionEditsAutoAccepted} ·",
                style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: PregoSpacing.xs),
            PregoButtonsSolid(
              key: const Key("session-edits-auto-accepted-turn-off"),
              label: loc.sessionEditsAutoAcceptedTurnOff,
              hierarchy: PregoButtonsSolidHierarchy.link,
              size: PregoButtonsSolidSize.xs,
              onPressed: onTurnOff,
            ),
          ],
        ),
      ),
    );
  }
}
