import "package:flutter/material.dart";

import "../../module_prego.dart";

/// The contextual subtitle row of the top navigation bar's back-leading title
/// block ([PregoNavLeadingTitle]), as instantiated on the sessions list
/// (Figma node 2386:11558): an optional status dot, an optional leading
/// [icon], the [text] and, when [infoMessage] is set, a chevron affordance
/// whose tap opens a [PregoInfoPopover] with the full message.
///
/// The row is self-contained — callers compose it (icon, dot, popover) and
/// hand the finished widget to [PregoGlassScaffold.subtitle] /
/// [PregoTopNavigation.subtitle] instead of threading row parts through the
/// bar's API.
class PregoNavSubtitle extends StatelessWidget {
  const PregoNavSubtitle({
    super.key,
    required this.text,
    this.icon,
    this.online,
    this.infoMessage,
    this.infoSemanticLabel,
  });

  /// The row's text, in `text-xs / medium / text-secondary`, clipped to a
  /// single ellipsised line.
  final String text;

  /// Optional icon rendered before the [text], sized to the row's `text-xs`
  /// glyphs.
  final IconData? icon;

  /// Status dot before the row: green (`fgSuccessSecondary`) when `true`,
  /// muted (`fgDisabledSubtle`) when `false`, absent when `null`.
  final bool? online;

  /// When set, the row becomes tappable: a trailing chevron-down is shown and
  /// tapping opens a [PregoInfoPopover] with this message (e.g. the
  /// untruncated form of an ellipsised [text]).
  final String? infoMessage;

  /// Screen-reader label for the tappable row; only used when [infoMessage]
  /// is set.
  final String? infoSemanticLabel;

  /// Status dot diameter — the Figma online-indicator size.
  static const double _dotSize = 6;

  /// Icon/chevron size, matching the row's `text-xs` glyph height.
  static const double _iconSize = 12;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final infoMessage = this.infoMessage;
    final online = this.online;
    final icon = this.icon;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: PregoSpacing.xs,
      children: [
        if (online != null)
          // Decorative for screen readers (a bare box has no semantics):
          // connection changes are announced by the scaffold's banner live
          // region, so the dot never needs to speak for itself.
          Container(
            width: _dotSize,
            height: _dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online ? prego.colors.fgSuccessSecondary : prego.colors.fgDisabledSubtle,
            ),
          ),
        if (icon != null) Icon(icon, size: _iconSize, color: prego.colors.textSecondary),
        Flexible(
          child: Text(
            text,
            style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (infoMessage != null) Icon(TablerRegular.chevron_down, size: _iconSize, color: prego.colors.textSecondary),
      ],
    );

    if (infoMessage == null) return row;

    return PregoInfoPopover(
      message: infoMessage,
      triggerBuilder: (_, toggle) => Semantics(
        button: true,
        label: infoSemanticLabel,
        // Put the tap action on the same node as the button role + label so
        // screen readers (VoiceOver/TalkBack) can activate the popover: a
        // child GestureDetector's tap action lands on a separate semantics
        // node the assistive-tech focus doesn't target.
        onTap: toggle,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: toggle,
          child: row,
        ),
      ),
    );
  }
}
