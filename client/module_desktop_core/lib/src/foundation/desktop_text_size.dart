/// How large the desktop window draws its text: a multiple of the type scale,
/// applied on top of the system's own text scaling.
enum DesktopTextSize({required final double scale}) {
  small(scale: 0.9),
  standard(scale: 1),
  large(scale: 1.15),
  larger(scale: 1.3);

  /// The next size up, or this one when it is already the largest.
  DesktopTextSize get bigger => DesktopTextSize.values[(index + 1).clamp(0, DesktopTextSize.values.length - 1)];

  /// The next size down, or this one when it is already the smallest.
  DesktopTextSize get smaller => DesktopTextSize.values[(index - 1).clamp(0, DesktopTextSize.values.length - 1)];
}
