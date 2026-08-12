import "package:flutter/material.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/interactions/prego_tappable.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";

/// The composer's advanced-options drawer: a pill that holds a chevron toggle
/// and expands accordion-style to reveal the actions that don't warrant a
/// permanent spot in the composer — the image-attach action and the
/// slash-commands picker.
///
/// Styled after the Figma `View options actions left` component: closed it
/// reads as a single round `pregoButtonsSolid` (44pt, skeuomorphic surface);
/// opened, each option is an icon button sharing that one joined background.
class const ComposerOptionsAccordion({
  super.key,

  /// Disables the revealed actions (not the toggle) while the composer is
  /// recording or transcribing, mirroring the old always-visible slash button.
  required final bool actionsEnabled,

  /// Whether the image-attach action is offered at all. Harnesses that drop
  /// image parts get no attach button rather than one that loses the image.
  required final bool showAttachImage,
  required final VoidCallback onSlashCommandsTap,
  required final VoidCallback onAttachImageTap,
}) extends StatefulWidget {
  @override
  State<ComposerOptionsAccordion> createState() => _ComposerOptionsAccordionState();
}

class _ComposerOptionsAccordionState() extends State<ComposerOptionsAccordion> {
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PregoRadius.full),
        child: Stack(
          children: [
            Padding(
              // 6pt insets centre the 32pt buttons in a 44pt-tall pill, so the
              // closed state is exactly the 44pt circle of the solid-button
              // neighbours. The chevron anchors at the trailing edge; revealed
              // actions slide out on the leading side, toward the field's
              // leading edge.
              padding: const EdgeInsets.all(PregoSpacing.sm),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: AlignmentDirectional.centerEnd,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isOpen) ...[
                      if (widget.showAttachImage) ...[
                        _AccordionIconButton(
                          icon: TablerRegular.photo,
                          tooltip: loc.sessionDetailAttachImage,
                          onTap: widget.actionsEnabled
                              ? () {
                                  setState(() => _isOpen = false);
                                  widget.onAttachImageTap();
                                }
                              : null,
                        ),
                        const SizedBox(width: PregoSpacing.md),
                      ],
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
                      const SizedBox(width: PregoSpacing.md),
                    ],
                    _AccordionIconButton(
                      icon: TablerRegular.chevron_right,
                      tooltip: _isOpen ? loc.sessionDetailHideActions : loc.sessionDetailMoreActions,
                      rotated: _isOpen,
                      onTap: () => setState(() => _isOpen = !_isOpen),
                    ),
                  ],
                ),
              ),
            ),
            PregoSkeuomorphicOverlay(
              innerBorderColor: prego.colors.skeuomorphicInnerBorder,
              bottomShadowColor: prego.colors.skeuomorphicShadow,
            ),
          ],
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
  final bool rotated = false,
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
