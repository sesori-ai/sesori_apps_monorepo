import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "turn_end_line.dart";

/// Inline display for a [MessageError].
///
/// A failure uses the transcript's leading alignment and body typography,
/// with error colour to distinguish a terminal failure from ongoing retry
/// activity. A turn the user stopped is no failure, so it ends with the quiet
/// [TurnEndLine] instead and never shows the harness's own wording.
class const ErrorMessageCard({
  super.key,
  required final MessageError message,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return switch (message.kind) {
      // A cancelled tool's icon, since a Stop cancels the turn.
      MessageErrorKind.stopped => TurnEndLine(icon: TablerSolid.circle_x, label: context.loc.sessionDetailTurnStopped),
      MessageErrorKind.failure => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            message.errorMessage,
            style: context.prego.textTheme.textSm.regular.copyWith(
              color: context.prego.colors.fgErrorPrimary,
            ),
          ),
        ),
      ),
    };
  }
}
