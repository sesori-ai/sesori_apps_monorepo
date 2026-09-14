import "dart:math" as math;

import "package:material_ui/material_ui.dart";

import "../../icons/tabler_icons.g.dart";
import "../../theme/prego_theme.dart";
import "../buttons/prego_buttons_solid.dart";

/// Composer inset from Figma's Queued msg list (4916:2220).
/// Three rows are visible; additional rows scroll independently of the chat.
class const PregoQueuedMessageList({
  super.key,
  required final List<PregoQueuedMessageRow> rows,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final prego = context.prego;
    // Preserve the 24px line box when accessibility text exceeds the 36px action.
    final rowHeight = math.max(36.0, MediaQuery.textScalerOf(context).scale(14) * 24 / 14) + 4;
    final radius = BorderRadius.circular(PregoRadius.x3l);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(color: prego.colors.borderPrimary),
        borderRadius: radius,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: prego.colors.bgSurface2,
          child: SizedBox(
            height: rowHeight * math.min(rows.length, 3),
            child: ListView(
              primary: false,
              padding: EdgeInsets.zero,
              itemExtent: rowHeight,
              physics: rows.length > 3 ? null : const NeverScrollableScrollPhysics(),
              children: rows,
            ),
          ),
        ),
      ),
    );
  }
}

class const PregoQueuedMessageRow({
  super.key,
  required final String preview,
  required final String statusLabel,
  required final String? warning,
  required final String removeLabel,
  required final VoidCallback? onRemove,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Semantics(
      label: statusLabel,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          PregoSpacing.lg,
          PregoSpacing.xxs,
          PregoSpacing.xxs,
          PregoSpacing.xxs,
        ),
        child: Row(
          spacing: PregoSpacing.md,
          children: [
            Expanded(
              child: Text(
                preview.replaceAll(RegExp(r"[\r\n]+"), " "),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: prego.textTheme.textSm.regular.copyWith(height: 24 / 14),
              ),
            ),
            if (warning case final warning?)
              Tooltip(
                message: warning,
                child: Icon(
                  TablerRegular.alert_circle,
                  size: 20,
                  color: prego.colors.fgErrorPrimary,
                  semanticLabel: warning,
                ),
              ),
            if (onRemove != null)
              Tooltip(
                message: removeLabel,
                child: PregoButtonsSolid.iconOnly(
                  leadingIcon: TablerRegular.trash,
                  hierarchy: PregoButtonsSolidHierarchy.tertiary,
                  size: PregoButtonsSolidSize.sm,
                  onPressed: onRemove,
                ),
              )
            else
              const SizedBox.square(dimension: 36),
          ],
        ),
      ),
    );
  }
}
