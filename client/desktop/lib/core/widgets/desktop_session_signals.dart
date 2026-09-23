import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:theme_prego/module_prego.dart";

/// A session's leading status column: two glyphs fill its [width] points. The
/// sidebar rows and the session page's title share it.
class const DesktopSessionSignals({
  super.key,
  required final bool isAwaitingInput,
  required final bool isRunning,
  required final bool isUnseen,
}) extends StatelessWidget {
  static const double width = 28;
  static const double _size = 14;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (isAwaitingInput)
        Tooltip(
          message: context.loc.sessionListAwaitingInput,
          child: Icon(
            TablerRegular.message_circle,
            size: _size,
            color: context.prego.colors.textWarningPrimary,
          ),
        ),
      if (isRunning || isUnseen)
        Tooltip(
          message: isRunning
              ? isUnseen
                    ? "${context.loc.projectListRunning(1)}, ${context.loc.projectListNewActivity}"
                    : context.loc.projectListRunning(1)
              : context.loc.projectListNewActivity,
          child: PregoAiLoader(size: _size, animate: isRunning),
        ),
    ],
  );
}
