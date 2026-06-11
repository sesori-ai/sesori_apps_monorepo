import "package:flutter/material.dart";

import "../extensions/build_context_x.dart";

/// The connection state a [ConnectionGraphic] depicts.
enum _ConnectionGraphicState { off, on }

/// Laptop illustration of the bridge connection state, exported as PNGs from
/// the Figma "Connection Graphic" component (node `1994:25434`).
///
/// Each state ships light and dark artwork (plus @2x/@3x variants); the image
/// matching the active light/dark mode is chosen at build time. Rendered at the
/// 141×101 Figma frame size.
///
/// Construct it with a named constructor, one per state:
/// * [ConnectionGraphic.connectionOff] — bridge disconnected: a dark laptop
///   screen with a broadcast-off badge.
/// * [ConnectionGraphic.connectionOn] — bridge connected: a green aurora glow
///   with a broadcast badge.
class ConnectionGraphic extends StatelessWidget {
  /// Bridge disconnected — a dark screen carrying a broadcast-off badge.
  const ConnectionGraphic.connectionOff({super.key}) : _state = _ConnectionGraphicState.off;

  /// Bridge connected — a green aurora glow carrying a broadcast badge.
  const ConnectionGraphic.connectionOn({super.key}) : _state = _ConnectionGraphicState.on;

  final _ConnectionGraphicState _state;

  static const String _dir = "assets/images/projects_onboarding/connection_graphic";
  static const String _offLight = "$_dir/connection_off-light.png";
  static const String _offDark = "$_dir/connection_off-dark.png";
  static const String _onLight = "$_dir/connection_on-light.png";
  static const String _onDark = "$_dir/connection_on-dark.png";

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final asset = switch (_state) {
      _ConnectionGraphicState.off => isDark ? _offDark : _offLight,
      _ConnectionGraphicState.on => isDark ? _onDark : _onLight,
    };
    return Image.asset(
      asset,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}
