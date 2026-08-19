import "package:flutter/widgets.dart";
import "package:widgetbook/widgetbook.dart";

/// Focused phone viewports for auditing compact, standard, and large layouts.
///
/// Android logical dimensions represent the default app viewport. A physical
/// device can report a different logical size when its display-size or system
/// navigation settings change.
abstract final class PregoCatalogViewports() {
  static const iPhone16Pro = ViewportData(
    name: "iPhone 16 Pro",
    width: 402,
    height: 874,
    pixelRatio: 3,
    platform: TargetPlatform.iOS,
    safeAreas: EdgeInsets.only(top: 62, bottom: 34),
  );

  static const iPhone16ProMax = ViewportData(
    name: "iPhone 16 Pro Max",
    width: 440,
    height: 956,
    pixelRatio: 3,
    platform: TargetPlatform.iOS,
    safeAreas: EdgeInsets.only(top: 62, bottom: 34),
  );

  static const pixel10Pro = ViewportData(
    name: "Google Pixel 10 Pro",
    width: 412,
    height: 915,
    pixelRatio: 3,
    platform: TargetPlatform.android,
    safeAreas: EdgeInsets.only(top: 24, bottom: 24),
  );

  static const galaxyS26Ultra = ViewportData(
    name: "Samsung Galaxy S26 Ultra",
    width: 384,
    height: 832,
    pixelRatio: 3.75,
    platform: TargetPlatform.android,
    safeAreas: EdgeInsets.only(top: 24, bottom: 24),
  );

  static const all = [
    Viewports.none,
    IosViewports.iPhoneSE,
    iPhone16Pro,
    iPhone16ProMax,
    pixel10Pro,
    galaxyS26Ultra,
  ];
}
