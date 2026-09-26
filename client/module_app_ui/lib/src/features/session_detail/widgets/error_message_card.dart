import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

/// Inline error display for a [MessageError].
///
/// Uses the transcript's leading alignment and body typography, with error
/// colour to distinguish a terminal failure from ongoing retry activity.
class const ErrorMessageCard({
  super.key,
  required final MessageError message,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
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
    );
  }
}
