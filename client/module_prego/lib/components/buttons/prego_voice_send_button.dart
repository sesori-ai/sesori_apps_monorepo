import "package:material_ui/material_ui.dart";

import "../../icons/tabler_icons.g.dart";
import "../../interactions/prego_tappable.dart";
import "../../theme/prego_theme.dart";

/// The corners of a button set in a pointer composer's corner: the composer's
/// 16 pt radius less the 6 pt it is inset by, so the two curves run parallel.
const double composerActionRadius = PregoRadius.x2l - PregoSpacing.sm;

/// The wide Send a pointer composer shows while a dictation runs, in the colours
/// of the Send button it grows out of.
///
/// The parent sets its width and may animate it: the label keeps its size and
/// stays centred instead of reflowing, and the fill clips it. Going [enabled]
/// false only dims it and stops it responding, so it can hold its place under
/// the cursor while the words arrive.
class const PregoVoiceSendButton({
  super.key,
  required final String label,
  required final bool enabled,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  static const double _dimmedOpacity = 0.4;
  static const Duration _dimDuration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;
    final radius = BorderRadius.circular(composerActionRadius);
    final foreground = colors.textPrimaryOnWhite;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: IgnorePointer(
        ignoring: !enabled,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : _dimmedOpacity,
          duration: _dimDuration,
          child: PregoTappable.stateAware(
            onTap: onPressed,
            borderRadius: radius,
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) return colors.alphaWhite20;
              if (states.contains(WidgetState.hovered)) return colors.alphaWhite10;
              return null;
            }),
            containerBuilder: ({required Widget child, required Set<WidgetState> state}) => DecoratedBox(
              decoration: BoxDecoration(
                color: colors.fgPrimary,
                borderRadius: radius,
                boxShadow: [BoxShadow(color: colors.shadowXs, offset: const Offset(0, 1), blurRadius: 2)],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: child,
              ),
            ),
            childBuilder: ({required Set<WidgetState> state}) => UnconstrainedBox(
              clipBehavior: Clip.hardEdge,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: PregoSpacing.xs,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    style: prego.textTheme.textSm.medium.copyWith(color: foreground),
                  ),
                  Icon(TablerRegular.arrow_up, size: PregoIconSize.sm, color: foreground),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
