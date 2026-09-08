import "package:flutter/animation.dart";

/// Finite arrival and dismissal motion, independent of preview tooling.
class const CatalogScanRowMotion({
  required final Duration entranceDuration,
  required final Duration collapseDuration,
  required final Curve entranceCurve,
  required final Curve collapseCurve,
  required final double entranceScaleFrom,
  required final double entranceBlurSigma,
}) {
  /// The production appearance; every consumer uses this unless tuning a preview.
  static const standard = CatalogScanRowMotion(
    entranceDuration: Duration(milliseconds: 260),
    collapseDuration: Duration(milliseconds: 260),
    entranceCurve: Cubic(0.23, 1, 0.32, 1),
    collapseCurve: Cubic(0.23, 1, 0.32, 1),
    entranceScaleFrom: 0.97,
    entranceBlurSigma: 2,
  );
}
