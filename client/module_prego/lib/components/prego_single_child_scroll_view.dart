import "package:material_ui/material_ui.dart";

/// A [SingleChildScrollView] that keeps its overscroll stretch when its content
/// lays out again.
///
/// [SingleChildScrollView] clamps its offset back to the content on every
/// layout. With a macOS trackpad the cursor rests while the content moves under
/// it, and a tooltip, text field or button that slides under the cursor lays
/// the content out again, so the stretch snaps back mid-gesture over and over.
/// A sliver viewport keeps the offset, so this places [child] in a
/// shrink-wrapping one, which sizes along the scroll axis as a
/// [SingleChildScrollView] does.
///
/// Across the scroll axis it fills the incoming limit and stretches [child] to
/// it, so use it where that limit is already tight.
class const PregoSingleChildScrollView({
  super.key,
  required final ScrollController? controller,
  final Axis scrollDirection = Axis.vertical,
  final bool reverse = false,
  final EdgeInsetsGeometry padding = EdgeInsets.zero,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => CustomScrollView(
    controller: controller,
    scrollDirection: scrollDirection,
    reverse: reverse,
    shrinkWrap: true,
    // The inherited physics, as a SingleChildScrollView keeps, so content that
    // fits stays still. Without a controller a CustomScrollView would otherwise
    // always scroll and bounce.
    physics: const ScrollPhysics(),
    slivers: [
      SliverPadding(
        padding: padding,
        sliver: SliverToBoxAdapter(child: child),
      ),
    ],
  );
}
