import "package:material_ui/material_ui.dart";
import "package:theme_prego/interactions/prego_tappable.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

/// The composer's advanced-options drawer: a chevron opens a pill containing
/// the image-attach action and slash-commands picker. Choosing an action
/// collapses the pill; the open state has no manual collapse control.
///
/// Matches Figma `View options actions left` (4602:14568): a flat bordered
/// 44pt pill with 32pt icon buttons separated by 8pt.
class const ComposerOptionsAccordion({
  super.key,

  /// Disables the revealed actions (not the opener) while the composer is
  /// recording or transcribing, mirroring the old always-visible slash button.
  required final bool actionsEnabled,

  /// Whether the image-attach action is offered at all. Harnesses that drop
  /// image parts get no attach button rather than one that loses the image.
  required final bool showAttachImage,

  /// Keeps `+` and `/` visible instead of folding them behind the chevron.
  required final bool alwaysOpen,
  required final VoidCallback onSlashCommandsTap,
  required final VoidCallback onAttachImageTap,
}) extends StatefulWidget {
  @override
  State<ComposerOptionsAccordion> createState() => _ComposerOptionsAccordionState();
}

class _ComposerOptionsAccordionState() extends State<ComposerOptionsAccordion> {
  bool _isOpen = false;

  /// After an action the pill folds again, unless it never folds.
  void _collapse() {
    if (widget.alwaysOpen) return;
    setState(() => _isOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final isOpen = _isOpen || widget.alwaysOpen;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: prego.colors.bgSurface4,
        borderRadius: BorderRadius.circular(PregoRadius.full),
        border: Border.all(color: prego.colors.borderPrimary),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PregoRadius.full),
        child: SizedBox(
          height: 44,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              // Figma uses a 3pt leading inset for the joined actions. Keep a
              // single button centred in a 44pt circle, including command-only
              // harnesses. Expansion remains anchored to the trailing edge.
              padding: EdgeInsetsDirectional.only(
                start: isOpen && widget.showAttachImage ? 3 : PregoSpacing.sm,
                end: PregoSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: PregoSpacing.md,
                children: [
                  if (isOpen) ...[
                    if (widget.showAttachImage)
                      _AccordionIconButton(
                        icon: TablerRegular.plus,
                        tooltip: loc.sessionDetailAttachImage,
                        onTap: widget.actionsEnabled
                            ? () {
                                _collapse();
                                widget.onAttachImageTap();
                              }
                            : null,
                      ),
                    _AccordionIconButton(
                      icon: TablerRegular.slash,
                      tooltip: loc.sessionDetailCommandPickerTitle,
                      onTap: widget.actionsEnabled
                          ? () {
                              _collapse();
                              widget.onSlashCommandsTap();
                            }
                          : null,
                    ),
                  ] else
                    _AccordionIconButton(
                      icon: TablerRegular.chevron_right,
                      tooltip: loc.sessionDetailMoreActions,
                      onTap: () => setState(() => _isOpen = true),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 32pt transparent circular icon button used inside the accordion pill.
class const _AccordionIconButton({
  required final IconData icon,
  required final String tooltip,
  required final VoidCallback? onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Tooltip(
      message: tooltip,
      child: PregoTappable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PregoRadius.full),
        containerBuilder: (Widget child) => SizedBox.square(dimension: 32, child: child),
        child: Icon(icon, size: PregoIconSize.md, color: prego.colors.textPrimary),
      ),
    );
  }
}
