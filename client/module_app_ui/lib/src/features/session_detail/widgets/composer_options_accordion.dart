import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/interactions/prego_tappable.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

/// The composer's advanced-options drawer: a chevron opens a pill containing
/// the image-attach action and slash-commands picker. Choosing an action or
/// starting to type collapses the pill; the open state has no manual collapse
/// control.
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

  /// Names what the attach action picks on this shell.
  required final String attachTooltip,

  /// Keeps `+` and `/` visible instead of folding them behind the chevron,
  /// except while [isTyping].
  required final bool alwaysOpen,

  /// Whether the composer holds text. Typing folds the actions away so the
  /// field gets the room; the chevron still reopens them.
  required final bool isTyping,
  required final VoidCallback onSlashCommandsTap,

  /// Where the attach action picks from. None holds its place disabled while
  /// support is still unknown, one opens straight away, and several open a
  /// menu to choose from.
  required final List<ComposerPickSource> attachSources,
  required final ValueChanged<ComposerPickSource> onAttach,

  /// Says whether the actions show, once it has built and whenever that changes,
  /// for what sits beside the pill to keep clear of them.
  required final ValueChanged<bool> onOpenChanged,
}) extends StatefulWidget {
  static const double _iconButtonSize = 32;

  /// Figma's leading inset for the joined actions.
  static const double _joinedStartInset = 3;

  /// The pill's width with its actions open, for placing things beside it without
  /// following its size as it gives way to other controls.
  static double openWidth({required bool showAttachImage}) => showAttachImage
      ? _joinedStartInset + _iconButtonSize + PregoSpacing.md + _iconButtonSize + PregoSpacing.sm
      : PregoSpacing.sm + _iconButtonSize + PregoSpacing.sm;

  @override
  State<ComposerOptionsAccordion> createState() => _ComposerOptionsAccordionState();
}

class _ComposerOptionsAccordionState() extends State<ComposerOptionsAccordion> {
  bool _isOpen = false;
  bool? _reportedOpen;

  @override
  void didUpdateWidget(ComposerOptionsAccordion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTyping && !oldWidget.isTyping) _isOpen = false;
  }

  /// After an action the pill folds again, unless it is open by default.
  void _collapse() {
    if (_isOpenByDefault) return;
    setState(() => _isOpen = false);
  }

  bool get _isOpenByDefault => widget.alwaysOpen && !widget.isTyping;

  /// After the frame: typing folds the pill while the composer above it builds.
  void _reportOpen({required bool isOpen}) {
    if (isOpen == _reportedOpen) return;
    _reportedOpen = isOpen;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onOpenChanged(isOpen);
    });
  }

  /// Eases the pill as it opens and folds. Reduced motion resizes at once: a
  /// zero-duration [AnimatedSize] would re-dirty itself mid-layout.
  Widget _easeWidth({required Widget child}) => context.isReducedMotion
      ? child
      : AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: AlignmentDirectional.centerEnd,
          child: child,
        );

  /// The plus. With several sources it opens a menu hung off itself, and the
  /// pill folds only once a source is chosen, so the menu keeps its anchor.
  Widget _buildAttachAction() {
    void attach(ComposerPickSource source) {
      _collapse();
      widget.onAttach(source);
    }

    switch (widget.attachSources) {
      case []:
        return _AccordionIconButton(icon: TablerRegular.plus, tooltip: widget.attachTooltip, onTap: null);
      case [final source]:
        return _AccordionIconButton(
          icon: TablerRegular.plus,
          tooltip: widget.attachTooltip,
          onTap: widget.actionsEnabled ? () => attach(source) : null,
        );
      case final sources:
        final loc = context.loc;
        return PregoAnchorMenu(
          flat: true,
          menuMaxHeight: null,
          menuWidth: 200,
          triggerBuilder: (context, toggle) => _AccordionIconButton(
            icon: TablerRegular.plus,
            tooltip: widget.attachTooltip,
            onTap: widget.actionsEnabled ? toggle : null,
          ),
          entriesBuilder: () => [
            for (final source in sources)
              PregoMenuItem(
                key: Key("composer-attach-${source.name}"),
                leadingIcon: switch (source) {
                  ComposerPickSource.photos => TablerRegular.photo,
                  ComposerPickSource.files => TablerRegular.file,
                },
                title: switch (source) {
                  ComposerPickSource.photos => loc.sessionDetailAttachFromPhotos,
                  ComposerPickSource.files => loc.sessionDetailAttachFromFiles,
                },
                subtitle: null,
                isSelected: false,
                shortcutLabel: null,
                // A menu left open when recording starts stops picking.
                isEnabled: widget.actionsEnabled,
                onTap: () => attach(source),
              ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final isOpen = _isOpen || _isOpenByDefault;
    _reportOpen(isOpen: isOpen);

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
          child: _easeWidth(
            child: Padding(
              // Keep a single button centred in a 44pt circle, including
              // command-only harnesses. Expansion remains anchored to the
              // trailing edge.
              padding: EdgeInsetsDirectional.only(
                start: isOpen && widget.showAttachImage ? ComposerOptionsAccordion._joinedStartInset : PregoSpacing.sm,
                end: PregoSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: PregoSpacing.md,
                children: [
                  if (isOpen) ...[
                    if (widget.showAttachImage) _buildAttachAction(),
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
    return PregoButtonSemantics(
      label: tooltip,
      enabled: onTap != null,
      showsTooltip: true,
      child: PregoTappable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PregoRadius.full),
        containerBuilder: (Widget child) =>
            SizedBox.square(dimension: ComposerOptionsAccordion._iconButtonSize, child: child),
        child: Icon(icon, size: PregoIconSize.md, color: prego.colors.textPrimary),
      ),
    );
  }
}
