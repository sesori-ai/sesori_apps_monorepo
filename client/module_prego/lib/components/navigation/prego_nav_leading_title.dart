import "package:flutter/material.dart";

import "../../module_prego.dart";

/// The left-aligned title block of the app's top navigation bar, matching the
/// `PregoTopNavigation` Figma component's "Back Leading" type as instantiated
/// on the sessions list (node 2386:11558): a muted [title] line over a
/// contextual subtitle row — an optional status dot, an optional leading
/// [subtitleIcon], the [subtitle] text and, when [infoMessage] is set, a
/// chevron affordance whose tap opens a [PregoInfoPopover] with the full
/// message.
///
/// Both lines are start-aligned and clipped to a single ellipsised line. The
/// whole block is deliberately muted (`text-secondary`): in this bar type the
/// page content carries the visual emphasis and the bar only identifies
/// context.
///
/// Rendered by [PregoTopNavigation] in its
/// [PregoTopNavigationTitleMode.backLeading] mode, sitting beside the back
/// button and bounded by the remaining bar width.
class PregoNavLeadingTitle extends StatelessWidget {
  const PregoNavLeadingTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.subtitleIcon,
    this.online,
    this.infoMessage,
    this.infoSemanticLabel,
  });

  /// First line, in `text-sm / medium / text-secondary`.
  final String title;

  /// The subtitle row's text. A `null` or empty value hides the whole row
  /// (status dot and icon included), leaving the title on its own.
  final String? subtitle;

  /// Optional icon rendered before the [subtitle] text, sized to the row's
  /// `text-xs` glyphs.
  final IconData? subtitleIcon;

  /// Status dot before the subtitle: green (`fgSuccessSecondary`) when `true`,
  /// muted (`fgDisabledSubtle`) when `false`, absent when `null`.
  final bool? online;

  /// When set, the subtitle row becomes tappable: a trailing chevron-down is
  /// shown and tapping opens a [PregoInfoPopover] with this message (e.g. the
  /// untruncated form of an ellipsised [subtitle]).
  final String? infoMessage;

  /// Screen-reader label for the tappable subtitle row; only used when
  /// [infoMessage] is set.
  final String? infoSemanticLabel;

  /// Status dot diameter — the Figma online-indicator size.
  static const double _dotSize = 6;

  /// Subtitle icon/chevron size, matching the row's `text-xs` glyph height.
  static const double _subtitleIconSize = 12;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final subtitle = this.subtitle;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: PregoSpacing.xs,
      children: [
        Text(
          title,
          style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null && subtitle.isNotEmpty) _buildSubtitleRow(context, subtitle: subtitle),
      ],
    );
  }

  Widget _buildSubtitleRow(BuildContext context, {required String subtitle}) {
    final prego = context.prego;
    final infoMessage = this.infoMessage;
    final online = this.online;
    final subtitleIcon = this.subtitleIcon;

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
        if (subtitleIcon != null) Icon(subtitleIcon, size: _subtitleIconSize, color: prego.colors.textSecondary),
        Flexible(
          child: Text(
            subtitle,
            style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (infoMessage != null)
          Icon(TablerRegular.chevron_down, size: _subtitleIconSize, color: prego.colors.textSecondary),
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
