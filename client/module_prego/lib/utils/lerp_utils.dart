import "dart:ui";

/// Non-null [Color.lerp] for interpolating between two non-null colors.
///
/// [Color.lerp] returns nullable because its inputs are nullable,
/// but when both inputs are non-null, the result is always non-null.
// ignore: no_slop_linter/prefer_required_named_parameters, tiny interpolation helpers intentionally mirror the underlying lerp signatures
Color lerpColorNonNull(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;

/// Non-null [lerpDouble] for interpolating between two non-null doubles.
///
/// [lerpDouble] returns nullable because its inputs are nullable,
/// but when both inputs are non-null, the result is always non-null.
// ignore: no_slop_linter/prefer_required_named_parameters, tiny interpolation helpers intentionally mirror the underlying lerp signatures
double lerpDoubleNonNull(double a, double b, double t) => lerpDouble(a, b, t) ?? a;
