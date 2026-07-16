import "package:flutter/material.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";

import "../../module_prego.dart";
import "../../utils/color_extensions.dart";

/// How [PregoTopNavigation] presents its title. The values map to the Figma
/// `PregoTopNavigation` component types.
enum PregoTopNavigationTitleMode {
  /// Figma "Large Title": the bar title fades in as the page's large title
  /// scrolls away (driven by [PregoTopNavigation.scrollController]).
  collapsing,

  /// Figma "Middle Title": a fixed, centred title (and subtitle).
  inline,

  /// Figma "Back Leading": a fixed, muted title/subtitle block left-aligned
  /// beside the back button.
  backLeading,
}

/// The app's glass top navigation bar — a [PreferredSizeWidget] wrapping the
/// `liquid_glass_widgets` [GlassAppBar].
///
/// The bar surface is transparent and glass is reserved for the buttons
/// ([PregoButtonsIconGlass]); the iOS-style scroll-edge fade is owned
/// by the enclosing [GlassScaffold], not painted
/// here. This follows the package's navigation showcase, which fades content
/// with the scaffold edge effect and reserves the glass (frost) effect for
/// buttons rather than frosting the bar surface itself.
///
/// It has three title modes ([titleMode]):
/// 1. **Collapsing** ([PregoTopNavigationTitleMode.collapsing], the default) —
///    a centred title fades in as a matching large title scrolls away. This
///    mode is driven by [scrollController] and is meant to pair with
///    [PregoGlassScaffold], which hosts the large title below the bar and owns
///    the controller. Without a [scrollController] the collapsing title never
///    appears.
/// 2. **Inline** ([PregoTopNavigationTitleMode.inline]) — a fixed, centred
///    [title] (and [subtitle]), rendered by [PregoNavTitle]. Self-contained;
///    use it for a standalone bar or for bodies that own their own scroll.
/// 3. **Back leading** ([PregoTopNavigationTitleMode.backLeading]) — a fixed,
///    muted [title]/[subtitle] block ([PregoNavLeadingTitle]) sitting
///    left-aligned beside the back button instead of centred, with optional
///    status dot, subtitle icon and info-popover affordance. There is no large
///    or centred title in this mode; [scrollController] is ignored.
///
/// [PregoGlassScaffold] and this bar share the collapse geometry through the
/// static [collapseProgressOf]: the bar fades its inline title *in* by that
/// value while the scaffold's large-title sliver fades *out* by its inverse.
///
/// Leading resolution (first match wins):
/// 1. an explicit [leading] widget;
/// 2. a glass back button ([PregoButtonsIconGlass]) wired to [onBack], for
///    routes whose poppable entry lives on a different navigator and so cannot
///    be inferred automatically;
/// 3. a glass back button that pops the enclosing route, when
///    [automaticallyImplyLeading] is set and the route is dismissible.
///
/// The bar never falls back to Flutter's stock Material [BackButton]: it renders
/// the glass button itself so the back affordance looks identical on every
/// screen.
///
/// Usage (standalone, fixed title):
/// ```dart
/// GlassScaffold(
///   appBar: PregoTopNavigation(title: loc.settingsTitle, titleMode: PregoTopNavigationTitleMode.inline),
///   body: ...,
/// )
/// ```
class PregoTopNavigation extends StatelessWidget implements PreferredSizeWidget {
  const PregoTopNavigation({
    super.key,
    required this.title,
    this.subtitle,
    this.titleMode = PregoTopNavigationTitleMode.collapsing,
    this.subtitleIcon,
    this.online,
    this.subtitleInfoMessage,
    this.subtitleInfoSemanticLabel,
    this.scrollController,
    this.actions,
    this.leading,
    this.onBack,
    this.automaticallyImplyLeading = true,
  });

  /// Primary title — fixed (inline and back-leading modes) or fading in as the
  /// large title collapses (collapsing mode), depending on [titleMode].
  final String title;

  /// Optional second line rendered beneath the [title] in a muted style. Only
  /// shown in the inline and back-leading modes; a `null` or empty value
  /// renders the title on its own.
  final String? subtitle;

  /// How the bar presents its title. See the class doc for the three modes.
  final PregoTopNavigationTitleMode titleMode;

  /// Optional icon before the [subtitle] text. Back-leading mode only.
  final IconData? subtitleIcon;

  /// Status dot before the [subtitle]: green when `true`, muted when `false`,
  /// absent when `null`. Back-leading mode only.
  final bool? online;

  /// When set (back-leading mode only), the subtitle row becomes tappable and
  /// opens an info popover with this message — see
  /// [PregoNavLeadingTitle.infoMessage].
  final String? subtitleInfoMessage;

  /// Screen-reader label for the tappable subtitle row; only used with
  /// [subtitleInfoMessage].
  final String? subtitleInfoSemanticLabel;

  /// Drives the collapsing title in non-inline mode: the bar fades its title in
  /// as this controller's offset crosses [collapseDistance]. Ignored in inline
  /// mode. Typically [PregoGlassScaffold]'s own controller.
  final ScrollController? scrollController;

  /// Trailing bar actions. Build these with [PregoButtonsIconGlass] so they
  /// match the leading/back button.
  final List<Widget>? actions;

  /// Overrides the leading slot entirely. Takes precedence over [onBack] and
  /// [automaticallyImplyLeading].
  final Widget? leading;

  /// When set (and [leading] is null), renders a glass back button that invokes
  /// this callback instead of relying on the enclosing navigator.
  final VoidCallback? onBack;

  /// Whether the bar may infer a back button from the navigator when neither
  /// [leading] nor [onBack] is supplied.
  final bool automaticallyImplyLeading;

  /// [GlassAppBar]'s content height — matches the Figma design. Bodies that own
  /// their own scroll behind the bar (see [PregoGlassScaffold] with
  /// `reserveBarSpace: false`) should take their top inset from
  /// [PregoTopBarInsetBuilder] — which adds the status bar and any inline
  /// banner — rather than from this constant alone.
  static const double barHeight = 54;

  /// Scroll distance over which the large title collapses into the bar — the
  /// value used by the showcase's `_LargeTitleCollapseDemo`.
  static const double collapseDistance = 52;

  /// Maps [controller]'s scroll offset to large-title collapse progress: 0 while
  /// the large title is fully shown, 1 once it has collapsed into the bar.
  ///
  /// Guards [ScrollController.hasClients] and a single attached position —
  /// during route transitions two scroll views can briefly share one controller
  /// and reading `offset` would throw. This is the single source of truth for
  /// the collapse: [PregoGlassScaffold] fades its large-title sliver out by the
  /// inverse of this value.
  static double collapseProgressOf(ScrollController controller) {
    if (!controller.hasClients || controller.positions.length != 1) {
      return 0;
    }
    return (controller.offset / collapseDistance).clamp(0.0, 1.0);
  }

  @override
  Size get preferredSize => const Size.fromHeight(barHeight);

  @override
  Widget build(BuildContext context) {
    final leading = _resolveLeading(context);
    return GlassAppBar(
      preferredSize: preferredSize,
      // Override GlassAppBar's default 8px inset so the leading and trailing
      // buttons sit 16pt from the bar edges. The full-width [title] content
      // pins flush to this padded area, so this padding is their distance from
      // the edge.
      padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xl),
      title: switch (titleMode) {
        PregoTopNavigationTitleMode.collapsing ||
        PregoTopNavigationTitleMode.inline => _buildCentredToolbar(leading: leading),
        PregoTopNavigationTitleMode.backLeading => _buildBackLeadingRow(leading: leading),
      },
    );
  }

  /// The centred-title layouts (collapsing and inline modes).
  ///
  /// [GlassAppBar] centres its title only within the gap *between* its own
  /// leading and actions slots, so a bar with a button on just one side (or
  /// with differently sized sides) pushes the title off-centre. Leave those
  /// slots empty and hand it a single full-width [NavigationToolbar] instead —
  /// the same layout Flutter's [AppBar] uses — so the title is centred across
  /// the whole bar and shifted only if it would otherwise overlap a side
  /// widget. (Do not move leading/trailing back onto GlassAppBar's slots: that
  /// reintroduces the off-centre title.)
  Widget _buildCentredToolbar({required Widget? leading}) {
    final actions = this.actions;
    return NavigationToolbar(
      centerMiddle: true,
      // NavigationToolbar stretches its leading slot to the full bar height
      // and top-aligns it, which would squash the circular glass back button
      // into an oval. Wrap it in an [Align] (widthFactor 1 so the slot is only
      // as wide as the button) to keep the button its natural size, vertically
      // centred. The trailing and middle slots are already laid out loose and
      // centred, so they need no such wrapper.
      leading: leading == null ? null : Align(widthFactor: 1, child: leading),
      // Inline mode: a fixed, centred title+subtitle (PregoNavTitle).
      // Collapsing mode: the title that fades in as the large title collapses.
      middle: titleMode == PregoTopNavigationTitleMode.inline
          ? PregoNavTitle(title: title, subtitle: subtitle)
          : _buildCollapsedTitle(),
      trailing: actions == null
          ? null
          : Row(mainAxisSize: MainAxisSize.min, spacing: PregoSpacing.md, children: actions),
    );
  }

  /// The back-leading layout: no centred middle exists in this type, so a
  /// plain [Row] replaces [NavigationToolbar] — back button, then the
  /// title/subtitle block filling the remaining width (bounding it so long
  /// titles ellipsise instead of overflowing, including narrow split-pane
  /// widths), then the trailing actions.
  Widget _buildBackLeadingRow({required Widget? leading}) {
    final actions = this.actions;
    return Row(
      children: [
        if (leading != null) ...[
          leading,
          const SizedBox(width: PregoSpacing.lg),
        ],
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: PregoNavLeadingTitle(
              title: title,
              subtitle: subtitle,
              subtitleIcon: subtitleIcon,
              online: online,
              infoMessage: subtitleInfoMessage,
              infoSemanticLabel: subtitleInfoSemanticLabel,
            ),
          ),
        ),
        if (actions != null) ...[
          const SizedBox(width: PregoSpacing.md),
          Row(mainAxisSize: MainAxisSize.min, spacing: PregoSpacing.md, children: actions),
        ],
      ],
    );
  }

  /// The bar's centred title — fades in as the large title collapses. Only built
  /// once the collapse has started so that, at rest, exactly one title is in the
  /// tree (the scaffold's large one) — keeping screen readers from announcing
  /// the title twice and matching `find.text` expectations.
  Widget _buildCollapsedTitle() {
    final controller = scrollController;
    if (controller == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final progress = collapseProgressOf(controller);
        if (progress == 0) return const SizedBox.shrink();
        final prego = context.prego;
        // Fade via text alpha instead of an Opacity layer — no saveLayer per frame.
        return Text(
          title,
          style: prego.textTheme.textXl.bold.copyWith(color: prego.colors.textPrimary.withMultipliedOpacity(progress)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }

  /// Resolves the leading bar button. Always renders the app's
  /// [PregoButtonsIconGlass] (never Flutter's stock [BackButton]) so the back
  /// affordance matches the design on every screen.
  Widget? _resolveLeading(BuildContext context) {
    final leading = this.leading;
    if (leading != null) return leading;

    final backAction =
        onBack ??
        ((automaticallyImplyLeading && (ModalRoute.of(context)?.impliesAppBarDismissal ?? false))
            // module_prego is a GoRouter-agnostic design module (no go_router
            // dependency), so this mirrors the stock BackButton's
            // Navigator.maybePop that AppBar would otherwise inject — identical
            // pop semantics to the implicit leading we are replacing.
            // ignore: no_slop_linter/avoid_navigator_of, design module has no go_router dep; replicates Flutter BackButton's Navigator.maybePop
            ? () => Navigator.maybePop(context)
            : null);
    if (backAction == null) return null;

    return PregoButtonsIconGlass(
      icon: TablerRegular.chevron_left,
      onPressed: backAction,
      // Announce the same "Back" affordance the stock BackButton would have, so
      // replacing it with the glass button keeps screen-reader parity.
      semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
    );
  }
}
