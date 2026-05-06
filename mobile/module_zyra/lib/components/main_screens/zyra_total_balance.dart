import "package:flutter/material.dart";

import "../../theme/zyra_theme.dart";
import "../../utils/lerp_utils.dart";
import "../zyra_rolling_text.dart";

/// Displays a formatted monetary balance with distinct styling for the
/// integer and fractional parts, matching the Figma `zyraTotalBalance` component.
///
/// The integer portion (currency symbol + whole number) is rendered in
/// `Display lg/Black` using the primary text color. The fractional cents are
/// rendered in `Display xs/Black` using the quaternary text color and are
/// baseline-aligned via a `Row` with `CrossAxisAlignment.baseline` for correct
/// alignment at any size.
///
/// The integer and fractional parts animate using [ZyraRollingText] based on
/// the [direction] parameter, which indicates whether the balance increased
/// (`.up`), decreased (`.down`), or should use per-character logic (`.perCharacter`).
///
/// [collapseProgress] drives the text size transition:
/// - `0.0` = fully expanded (`Display lg` / `Display xs`)
/// - `1.0` = fully collapsed (`Display md` / `Text xl`)
///
/// Example:
/// ```dart
/// ZyraTotalBalance(
///   currencySymbol: r'$',
///   integerPart: '25,310',
///   fractionalPart: '04',
///   collapseProgress: 0.0,
///   direction: ZyraRollingTextDirection.up,
/// )
/// ```
class ZyraTotalBalance extends StatelessWidget {
  const ZyraTotalBalance({
    super.key,
    required this.currencySymbol,
    required this.integerPart,
    required this.fractionalPart,
    required this.collapseProgress,
    required this.direction,
  });

  /// The currency symbol displayed before the integer part (e.g. `$`).
  final String currencySymbol;

  /// The whole-number portion of the balance (e.g. `25,310`).
  final String integerPart;

  /// The fractional/cents portion of the balance (e.g. `04`).
  /// Does NOT include the decimal separator — that is rendered separately.
  final String fractionalPart;

  /// Collapse progress for scroll-driven size transitions.
  /// - `0.0` = fully expanded (Display lg / Display xs)
  /// - `1.0` = fully collapsed (Display md / Text lg)
  final double collapseProgress;

  /// Direction for rolling text animation.
  /// - `.up` = balance increased
  /// - `.down` = balance decreased
  /// - `.perCharacter` = each character determines its own direction
  final ZyraRollingTextDirection direction;

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;
    final colors = zyra.colors;
    final textTheme = zyra.textTheme;
    final t = collapseProgress.clamp(0.0, 1.0);

    final mainStyle = lerpTextStyleNonNull(
      textTheme.displayLg.black,
      textTheme.displayMd.black,
      t,
    ).copyWith(color: colors.textPrimary);
    final centsStyle = lerpTextStyleNonNull(
      textTheme.displayXs.black,
      textTheme.textXl.black,
      t,
    ).copyWith(color: colors.textQuaternary);

    final child = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(currencySymbol, style: mainStyle),
        ZyraRollingText(
          text: integerPart,
          style: mainStyle,
          direction: direction,
        ),
        Text(".", style: centsStyle),
        ZyraRollingText(
          text: fractionalPart,
          style: centsStyle,
          direction: direction,
        ),
      ],
    );

    // Wrapped to scale down the balance text to fit within the available space.
    // This is necessary because the balance text can be very long and may not fit
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.center,
      child: child,
    );
  }
}
