import "package:flutter/material.dart";
import "package:theme_prego/interactions/prego_tappable.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";

/// The composer's advanced-options drawer: a pill that holds a chevron toggle
/// and expands accordion-style to reveal the actions that don't warrant a
/// permanent spot in the composer — today just the slash-commands picker,
/// later things like attaching files or images.
class ComposerOptionsAccordion extends StatefulWidget {
  /// Disables the revealed actions (not the toggle) while the composer is
  /// recording or transcribing, mirroring the old always-visible slash button.
  final bool actionsEnabled;
  final VoidCallback onSlashCommandsTap;

  const ComposerOptionsAccordion({
    super.key,
    required this.actionsEnabled,
    required this.onSlashCommandsTap,
  });

  @override
  State<ComposerOptionsAccordion> createState() => _ComposerOptionsAccordionState();
}

class _ComposerOptionsAccordionState extends State<ComposerOptionsAccordion> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: prego.colors.bgSurface4,
        borderRadius: BorderRadius.circular(PregoRadius.full),
        border: Border.all(color: prego.colors.borderPrimary),
        boxShadow: [
          BoxShadow(color: prego.colors.shadowXs, offset: const Offset(0, 1), blurRadius: 2),
        ],
      ),
      child: Padding(
        // Chevron hugs the trailing edge (Figma: 3/2/6/2) so the pill reads as
        // opening toward the field; revealed actions slide out on the leading
        // side.
        padding: const EdgeInsetsDirectional.fromSTEB(3, 2, 6, 2),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: AlignmentDirectional.centerEnd,
          child: SizedBox(
            height: 40,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isOpen) ...[
                  _AccordionIconButton(
                    icon: TablerRegular.slash,
                    tooltip: loc.sessionDetailCommandPickerTitle,
                    onTap: widget.actionsEnabled
                        ? () {
                            setState(() => _isOpen = false);
                            widget.onSlashCommandsTap();
                          }
                        : null,
                  ),
                  const SizedBox(width: 2),
                ],
                _AccordionIconButton(
                  icon: TablerRegular.chevron_right,
                  tooltip: loc.sessionDetailMoreActions,
                  rotated: _isOpen,
                  onTap: () => setState(() => _isOpen = !_isOpen),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A 32pt transparent circular icon button used inside the accordion pill.
class _AccordionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool rotated;
  final VoidCallback? onTap;

  const _AccordionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.rotated = false,
  });

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Tooltip(
      message: tooltip,
      child: PregoTappable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PregoRadius.full),
        containerBuilder: (Widget child) => SizedBox.square(dimension: 32, child: child),
        child: AnimatedRotation(
          turns: rotated ? 0.5 : 0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: Icon(icon, size: 18, color: prego.colors.textPrimary),
        ),
      ),
    );
  }
}
