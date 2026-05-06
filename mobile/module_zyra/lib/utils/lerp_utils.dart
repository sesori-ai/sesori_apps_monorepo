import "dart:ui";

import "package:flutter/painting.dart";

/// Non-null [Color.lerp] for interpolating between two non-null colors.
///
/// [Color.lerp] returns nullable because its inputs are nullable,
/// but when both inputs are non-null, the result is always non-null.
// ignore: no_slop_linter/prefer_required_named_parameters
Color lerpColorNonNull(Color a, Color b, double t) =>
    Color.lerp(a, b, t)!; // ignore: no_slop_linter/avoid_bang_operator

/// Non-null [lerpDouble] for interpolating between two non-null doubles.
///
/// [lerpDouble] returns nullable because its inputs are nullable,
/// but when both inputs are non-null, the result is always non-null.
// ignore: no_slop_linter/prefer_required_named_parameters
double lerpDoubleNonNull(double a, double b, double t) =>
    lerpDouble(a, b, t)!; // ignore: no_slop_linter/avoid_bang_operator

/// Non-null [TextStyle.lerp] for interpolating between two non-null text styles.
///
/// [TextStyle.lerp] returns nullable because its inputs are nullable,
/// but when both inputs are non-null, the result is always non-null.
// ignore: no_slop_linter/prefer_required_named_parameters
TextStyle lerpTextStyleNonNull(TextStyle a, TextStyle b, double t) =>
    TextStyle.lerp(a, b, t)!; // ignore: no_slop_linter/avoid_bang_operator
