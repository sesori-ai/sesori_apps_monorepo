import "package:flutter/material.dart";

import "../extensions/build_context_x.dart";

/// The connection state a [ConnectionGraphic] depicts.
enum _ConnectionGraphicState { off, on }

/// Laptop illustration of the bridge connection state, exported as PNGs from
/// the Figma "Connection Graphic" component (node `3773:10041`).
///
/// Each state ships light and dark artwork (plus @2x/@3x variants); the image
/// matching the active light/dark mode is chosen at build time. Rendered at the
/// 208×109 Figma frame size.
///
/// Construct it with a named constructor, one per state:
/// * [ConnectionGraphic.connectionOff] — bridge disconnected: a greyed laptop
///   shell with a muted broadcast-off badge.
/// * [ConnectionGraphic.connectionOn] — bridge connected: a laptop shell
///   filled with an aurora glow and a green broadcast badge.
class ConnectionGraphic extends StatelessWidget {
  /// Bridge disconnected — a greyed shell carrying a broadcast-off badge.
  const ConnectionGraphic.connectionOff({super.key}) : _state = _ConnectionGraphicState.off;

  /// Bridge connected — an aurora-filled shell carrying a broadcast badge.
  const ConnectionGraphic.connectionOn({super.key}) : _state = _ConnectionGraphicState.on;

  final _ConnectionGraphicState _state;

  /// The Figma frame the artwork is drawn at, pinned explicitly rather than
  /// taken from the decoded asset.
  ///
  /// An unsized [Image] reports a *max intrinsic* height of
  /// `crossAxisExtent / aspectRatio` — the height it would need if stretched to
  /// the full available width — not the height it paints at. The onboarding
  /// bodies hang under `SliverFillRemaining(hasScrollBody: false)`, which sizes
  /// itself from that intrinsic, so an unsized graphic would inflate the page's
  /// scroll extent by ~180pt of empty space below the content.
  static const double _width = 208;
  static const double _height = 109;

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
      width: _width,
      height: _height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}
