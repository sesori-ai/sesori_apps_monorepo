import "dart:async";
import "dart:math" as math;

import "package:cue/cue.dart";
import "package:flutter/material.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";

import "../../theme/prego_glass.dart";
import "../../theme/prego_theme.dart";
import "anchored_flat_panel.dart";
import "anchored_spotlight_backdrop.dart";

/// A single entry in a [PregoAnchorMenu].
///
/// Entries are plain data, not pre-built widgets, so one call site renders
/// either the liquid-glass items ([GlassMenuItem] et al. on iOS) or flat
/// Material rows (Android) without the caller knowing which path is active.
sealed class PregoMenuEntry {
  const PregoMenuEntry();
}

/// A non-interactive section header. Rendered in uppercase on both paths.
class PregoMenuLabel extends PregoMenuEntry {
  const PregoMenuLabel({required this.text});

  final String text;
}

/// A tappable menu row with a [title], optional [subtitle], an optional
/// [leadingIcon], and an optional selected check mark. Tapping runs [onTap] and
/// dismisses the menu.
class PregoMenuItem extends PregoMenuEntry {
  const PregoMenuItem({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.leadingIcon,
    this.isDestructive = false,
  });

  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  /// Optional glyph shown before the title. Rendered identically on the glass
  /// and flat paths (muted to the secondary text colour).
  final IconData? leadingIcon;

  /// Marks an action that destroys something the user cannot get back (delete,
  /// not archive). Tints the title and glyph with the error colour on both
  /// paths. Reach for it sparingly — a menu where several rows shout stops any
  /// of them being heard.
  final bool isDestructive;
}

/// A thin separator line between entries.
class PregoMenuDivider extends PregoMenuEntry {
  const PregoMenuDivider();
}

/// An escape hatch for a custom row (e.g. a search affordance pinned at the top
/// of the menu).
///
/// [builder] receives a `close` callback that dismisses the menu — use it to
/// collapse the popup before, say, raising a full-screen sheet.
class PregoMenuCustom extends PregoMenuEntry {
  const PregoMenuCustom({required this.builder, required this.height});

  final Widget Function(BuildContext context, VoidCallback close) builder;

  /// The row's rendered height, which the caller must state.
  ///
  /// The glass popup lays itself out from declared row heights rather than by
  /// measuring (see [_glassItemHeight]), and it cannot measure a widget it did
  /// not build. Getting this wrong under-sizes the popup, so keep it in step
  /// with what [builder] returns. The flat path measures for real and ignores
  /// it.
  final double height;
}

/// Builds the trigger that opens the menu. [toggle] opens (or, on the glass
/// path, toggles) the popup — wire it to the trigger's tap handler.
typedef PregoMenuTriggerBuilder = Widget Function(BuildContext context, VoidCallback toggle);

/// Blurs and dims the page behind an open [PregoAnchorMenu], cutting a sharp
/// hole around the trigger so it stays legible and reads as lifted out of the
/// blur — the iOS context-menu treatment for a long-pressed list row.
///
/// Only the flat path can spotlight. The glass path's [GlassMenu] hides its own
/// trigger while the popup is up and morphs the popup out of the trigger's
/// bounds, so there is nothing left to keep sharp; [PregoAnchorMenu] asserts the
/// pairing rather than letting the option silently do nothing.
class PregoMenuSpotlight {
  const PregoMenuSpotlight({
    required this.borderRadius,
    this.inset = EdgeInsets.zero,
  });

  /// Corner radius of the sharp cut-out.
  final double borderRadius;

  /// Shrinks the cut-out relative to the trigger's bounds. A full-width list row
  /// insets horizontally so the sharp region reads as a lifted card rather than
  /// a full-bleed band running into the screen edges.
  final EdgeInsets inset;

  /// The region to keep sharp for a trigger occupying [triggerRect].
  ///
  /// An [inset] larger than the trigger would flip the rect inside out and hand
  /// a negative-size rect to the backdrop's cut-out and outline; the trigger's
  /// raw bounds win over the inset in that case.
  Rect resolveRect({required Rect triggerRect}) {
    final deflated = inset.deflateRect(triggerRect);
    return (deflated.width < 0 || deflated.height < 0) ? triggerRect : deflated;
  }

  /// The treatment for a long-pressed full-width list row: the cut-out is inset
  /// from the screen edges so the sharp region reads as a lifted card rather
  /// than a full-bleed band. One shared preset so every long-pressable row gets
  /// the identical spotlight.
  static const listRow = PregoMenuSpotlight(
    borderRadius: 16,
    inset: EdgeInsets.symmetric(horizontal: 8),
  );
}

/// A popup menu that anchors to its trigger, rendered platform-appropriately.
///
/// On Apple platforms it is the `liquid_glass_widgets` [GlassMenu] — the
/// iOS-26 liquid-glass popup that morphs out of the trigger. On Android, where
/// the glass shader + backdrop blur jank, it falls back to a flat Material panel
/// anchored to the trigger and animated with the `cue` package's spring physics
/// (a [CueModalTransition]) — same anchored-popup behaviour, zero shader cost.
///
/// The same [entriesBuilder] and [triggerBuilder] drive both paths; only the
/// rendering differs. See [glassEffectsEnabled] for the platform switch. Set [flat] to
/// force the flat/`cue` path on every platform (including Apple) — for a menu
/// paired with a flat trigger, where a glass popup would look out of place.
class PregoAnchorMenu extends StatefulWidget {
  const PregoAnchorMenu({
    super.key,
    required this.triggerBuilder,
    required this.entriesBuilder,
    this.menuWidth = 240,
    this.menuMaxHeight,
    this.menuBorderRadius = 24,
    this.menuScreenPadding = const EdgeInsets.all(12),
    this.flat = false,
    this.spotlight,
  }) : assert(
         spotlight == null || flat,
         "A spotlight needs the flat path (flat: true): GlassMenu hides its trigger while the "
         "popup is up, so there is no trigger left to keep sharp.",
       );

  /// Builds the tappable trigger. The provided callback opens the menu.
  final PregoMenuTriggerBuilder triggerBuilder;

  /// Builds the menu contents, top to bottom. A builder rather than a list so
  /// a trigger hosted in a frequently-rebuilding row (a live-updating list
  /// tile) pays nothing for a closed menu: the flat path calls it only when the
  /// menu opens. The glass path materialises it at build time — [GlassMenu]
  /// takes its items up front.
  final List<PregoMenuEntry> Function() entriesBuilder;

  /// Width of the open menu.
  final double menuWidth;

  /// Caps how tall the open menu may grow; beyond it the rows scroll. Null (the
  /// default) lets the menu grow with its content, which both paths still bound
  /// to the room they have — the screen on the glass path, the space beside the
  /// trigger on the flat one.
  ///
  /// The menu measures its own rows, so a cap is a product decision ("don't let
  /// this swallow the screen"), never a guess at how tall the rows are. A menu
  /// shorter than its cap is sized exactly to its content, not padded out to it.
  final double? menuMaxHeight;

  /// Corner radius of the open menu.
  final double menuBorderRadius;

  /// Minimum gap kept between the menu and the screen edges.
  final EdgeInsets menuScreenPadding;

  /// Forces the flat/`cue` path on every platform when `true`. When `false`
  /// (the default) the path follows [glassEffectsEnabled] — glass on Apple,
  /// flat on Android.
  final bool flat;

  /// When set, the open menu blurs and dims the page behind it while keeping the
  /// trigger sharp. Null (the default) leaves the backdrop untouched — right for
  /// a menu hung off a button, where the page behind it is not the subject.
  /// Requires [flat]; see [PregoMenuSpotlight].
  final PregoMenuSpotlight? spotlight;

  @override
  State<PregoAnchorMenu> createState() => _PregoAnchorMenuState();
}

class _PregoAnchorMenuState extends State<PregoAnchorMenu> {
  /// Drives the glass popup imperatively so a [PregoMenuCustom] entry can close
  /// the menu before escalating (e.g. into a full-screen sheet). `late` so it is
  /// only constructed when the glass path actually reads it — never on Android.
  late final GlassMenuController _glassController = GlassMenuController();

  @override
  Widget build(BuildContext context) {
    final useGlass = !widget.flat && glassEffectsEnabled();
    return useGlass ? _buildGlass(context) : _buildFlat(context);
  }

  // ── Glass path (Apple) ─────────────────────────────────────────────────────

  Widget _buildGlass(BuildContext context) {
    final entries = widget.entriesBuilder();
    return GlassMenu(
      controller: _glassController,
      menuWidth: widget.menuWidth,
      menuHeight: _glassHeight(context, entries: entries),
      menuBorderRadius: widget.menuBorderRadius,
      autoAdjustToScreen: true,
      menuPadding: widget.menuScreenPadding,
      settings: LiquidGlassSettings(glassColor: context.prego.colors.buttonGlassPrimaryBackground),
      triggerBuilder: (context, toggle) => widget.triggerBuilder(context, () {
        toggle();
        _alignGlassMenuToTrigger(context);
      }),
      items: [for (final entry in entries) _glassEntry(context, entry: entry)],
    );
  }

  /// The fixed height to pin the glass popup at, or null to let it grow with its
  /// rows.
  ///
  /// [GlassMenu] has no notion of a maximum: a height either pins it (and it
  /// scrolls inside) or is absent (and it wraps its rows, bounded by the
  /// screen). [menuMaxHeight] is honoured by pinning it only once the rows
  /// actually outgrow the cap — below that the popup wraps them exactly, with no
  /// dead glass at the bottom.
  double? _glassHeight(BuildContext context, {required List<PregoMenuEntry> entries}) {
    final cap = widget.menuMaxHeight;
    if (cap == null) return null;
    // GlassMenu's own column chrome: 12px above the first row, 12px below the
    // last, 2px between neighbours.
    var natural = 24.0 + math.max(0, entries.length - 1) * 2.0;
    for (final entry in entries) {
      natural += _glassEntryHeight(context, entry: entry);
    }
    return natural > cap ? cap : null;
  }

  /// Re-anchors the just-opened glass popup under its trigger when the composer
  /// is hosted in a master-detail right pane (landscape/split layouts).
  ///
  /// [GlassMenu] captures its trigger in global (screen) coordinates but paints
  /// the popup inside the enclosing [Overlay], which in a split layout is inset
  /// from the screen by the sidebar width — so the popup lands one sidebar-width
  /// off along the main axis. Feeding the negated Overlay origin as a
  /// follow-offset cancels that inset. A no-op in single-pane layouts (the
  /// Overlay sits at the screen origin); the flat path needs none of this — it
  /// positions against the root navigator already.
  ///
  /// Called right after [GlassMenu]'s toggle: opening resets the follow-offset
  /// to zero, and this re-applies the correction on top.
  void _alignGlassMenuToTrigger(BuildContext context) {
    final overlayBox = Overlay.maybeOf(context)?.context.findRenderObject();
    if (overlayBox is! RenderBox || !overlayBox.attached || !overlayBox.hasSize) return;
    _glassController.setFollowOffset(-overlayBox.localToGlobal(Offset.zero));
  }

  Widget _glassEntry(BuildContext context, {required PregoMenuEntry entry}) {
    final prego = context.prego;
    switch (entry) {
      case PregoMenuLabel(:final text):
        // GlassMenuLabel uppercases the title itself; we only supply the style.
        return GlassMenuLabel(
          title: text,
          style: _labelStyle(prego),
          height: _glassLabelHeight(context),
        );
      case PregoMenuItem(
        :final title,
        :final subtitle,
        :final isSelected,
        :final onTap,
        :final leadingIcon,
        :final isDestructive,
      ):
        return GlassMenuItem(
          title: title,
          subtitle: subtitle,
          isSelected: isSelected,
          height: _glassItemHeight(context, hasSubtitle: subtitle != null),
          // GlassMenuItem would paint a destructive row in Cupertino's system
          // red; the explicit style below keeps it on the design system's error
          // token instead. The flag still drives its press feedback.
          isDestructive: isDestructive,
          icon: leadingIcon == null
              ? null
              : Icon(leadingIcon, size: 20, color: _iconColor(prego, isDestructive: isDestructive)),
          titleStyle: _titleStyle(prego, isDestructive: isDestructive),
          subtitleStyle: _subtitleStyle(prego),
          trailing: isSelected ? _selectedCheck(prego) : null,
          onTap: onTap,
        );
      case PregoMenuDivider():
        return const GlassMenuDivider(height: _glassDividerHeight);
      case PregoMenuCustom(:final builder, :final height):
        // Hosted in a GlassMenuLabel — the one non-interactive row GlassMenu
        // will take a height from. Handed back raw, the row would be budgeted at
        // GlassMenu's 44px fallback for widgets it does not recognise, which
        // under-sizes the popup. The label is pure chrome here (no title, no
        // padding of its own), so the custom widget renders unchanged.
        return GlassMenuLabel(
          height: height,
          horizontalPadding: 0,
          child: builder(context, _glassController.close),
        );
    }
  }

  // ── Flat path (Android) ────────────────────────────────────────────────────

  Widget _buildFlat(BuildContext context) {
    final spotlight = widget.spotlight;
    return CueModalTransition(
      barrierColor: Colors.transparent,
      motion: const Spring.smooth(),
      reverseMotion: const Spring.snappy(),
      // No alignment: the panel positions itself from the trigger rect so it can
      // clamp to the screen edges, mirroring GlassMenu.autoAdjustToScreen.
      triggerBuilder: (context, showModal) =>
          widget.triggerBuilder(context, () => unawaited(showModal())),
      builder: (context, triggerRect) {
        final panel = _flatPanel(context, triggerRect: triggerRect);
        if (spotlight == null) return panel;
        // The backdrop is stacked here rather than passed as CueModalTransition's
        // `backdrop`, which is a plain widget and so cannot see the trigger rect
        // it must cut its hole around. Both children fill the route; the panel
        // paints last, over the blur.
        return Stack(
          fit: StackFit.expand,
          children: [
            AnchoredSpotlightBackdrop(
              spotlightRect: spotlight.resolveRect(triggerRect: triggerRect),
              borderRadius: spotlight.borderRadius,
            ),
            panel,
          ],
        );
      },
    );
  }

  Widget _flatPanel(BuildContext context, {required Rect triggerRect}) {
    final entries = widget.entriesBuilder();
    final edgePadding = EdgeInsets.only(
      top: entries.isEmpty || entries.first is! PregoMenuItem ? 6 : 0,
      bottom: entries.isEmpty || entries.last is! PregoMenuItem ? 6 : 0,
    );
    return AnchoredFlatPanel(
      triggerRect: triggerRect,
      width: widget.menuWidth,
      // The panel measures its rows for real, so the cap is all it needs: it
      // shrink-wraps below it and scrolls above it.
      maxHeight: widget.menuMaxHeight,
      borderRadius: widget.menuBorderRadius,
      screenPadding: widget.menuScreenPadding,
      // Menu items meet the panel clip so their ink reaches its outer edges.
      // Labels, dividers, and custom content keep the original edge breathing
      // room when they bookend the menu.
      childBuilder: (context, close) => Padding(
        padding: edgePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in entries) _flatEntry(context, entry: entry, close: close),
          ],
        ),
      ),
    );
  }

  Widget _flatEntry(BuildContext context, {required PregoMenuEntry entry, required VoidCallback close}) {
    final prego = context.prego;
    switch (entry) {
      case PregoMenuLabel(:final text):
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 4),
          // Uppercased to match GlassMenuLabel on the glass path.
          child: Text(text.toUpperCase(), style: _labelStyle(prego)),
        );
      case PregoMenuItem(
        :final title,
        :final subtitle,
        :final isSelected,
        :final onTap,
        :final leadingIcon,
        :final isDestructive,
      ):
        return _FlatMenuTile(
          title: title,
          subtitle: subtitle,
          isSelected: isSelected,
          leadingIcon: leadingIcon,
          isDestructive: isDestructive,
          onTap: () {
            close();
            onTap();
          },
        );
      case PregoMenuDivider():
        return Divider(
          height: 12,
          thickness: 0.5,
          indent: 8,
          endIndent: 8,
          color: prego.colors.borderSecondary,
        );
      case PregoMenuCustom(:final builder):
        return builder(context, close);
    }
  }
}

/// A single flat menu row — the Android counterpart of [GlassMenuItem], styled
/// to match its glass sibling (same 44px min height, title/subtitle/check layout).
class _FlatMenuTile extends StatelessWidget {
  const _FlatMenuTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    required this.isDestructive,
    this.leadingIcon,
  });

  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDestructive;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final subtitle = this.subtitle;
    final leadingIcon = this.leadingIcon;
    return InkWell(
      onTap: onTap,
      // The enclosing Material clips the menu to its configured radius. A
      // second radius here would round the shared edges between adjacent rows.
      borderRadius: BorderRadius.zero,
      child: ConstrainedBox(
        // Matches GlassMenuItem's 44px iOS/Material touch target.
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (leadingIcon != null) ...[
                Icon(leadingIcon, size: 20, color: _iconColor(prego, isDestructive: isDestructive)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _titleStyle(prego, isDestructive: isDestructive),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty)
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _subtitleStyle(prego)),
                  ],
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                _selectedCheck(prego),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared entry styling (keeps the glass and flat paths visually identical) ──

// ── Glass row heights ────────────────────────────────────────────────────────
//
// [GlassMenu] never measures its rows: it lays the popup out from the heights
// its items *declare* (`GlassMenuItem.height` and friends), falling back to a
// guess at the text height — `fontSize × 1.2` per line, floored at a 44px touch
// target — when a row leaves that height at its default. The design system's
// rows are taller than that guess: `textSm` sits in a 20px line box and `textXs`
// in an 18px one, so a title-plus-subtitle row really occupies 54px against a
// guessed 47.
//
// Under-declaring is not just a cosmetic under-size. Those same heights are what
// GlassMenu sums to size the popup, what it uses to place the selection pill,
// and — for a popup short enough not to scroll — what it does index arithmetic
// over to decide which row a tap landed on. Guess low and the last row is
// clipped with no way to scroll to it, and taps near a row's lower edge fire the
// row *below* the one under the finger.
//
// So every row we hand GlassMenu declares its true height, computed here from
// the very styles the row is rendered with. `prego_anchor_menu_test` pins each
// declaration against the height the row actually renders at, so a package
// upgrade that changes a row's chrome fails there rather than in the field.

/// Height of a [PregoMenuItem]'s glass row: [GlassMenuItem]'s 8px of padding
/// above and below a title, plus a subtitle line when it carries one.
double _glassItemHeight(BuildContext context, {required bool hasSubtitle}) {
  const verticalPadding = 16.0;
  final prego = context.prego;
  var text = _lineHeight(context, style: _titleStyle(prego, isDestructive: false));
  if (hasSubtitle) text += _lineHeight(context, style: _subtitleStyle(prego));
  // Never below the 44px touch target GlassMenuItem floors its rows at.
  return math.max(44, verticalPadding + text);
}

/// Height of a [PregoMenuLabel]'s glass row. [GlassMenuLabel] pins its box to
/// the declared height, so it must clear the label's line box — at a large text
/// scale that outgrows the 30px the package would otherwise assume.
double _glassLabelHeight(BuildContext context) =>
    math.max(30, _lineHeight(context, style: _labelStyle(context.prego)));

/// Height of a [PregoMenuDivider]'s glass row — [GlassMenuDivider]'s own
/// default, named so the height budget can account for it.
const double _glassDividerHeight = 12;

/// The height [GlassMenu] will budget for [entry] — which is exactly the height
/// the row renders at, because every row above declares its own.
///
/// Exposed (via [debugGlassEntryHeight]) to the test that pins each declaration
/// against the rendered row.
double _glassEntryHeight(BuildContext context, {required PregoMenuEntry entry}) => switch (entry) {
  PregoMenuLabel() => _glassLabelHeight(context),
  PregoMenuItem(:final subtitle) => _glassItemHeight(context, hasSubtitle: subtitle != null),
  PregoMenuDivider() => _glassDividerHeight,
  PregoMenuCustom(:final height) => height,
};

@visibleForTesting
double debugGlassEntryHeight(BuildContext context, {required PregoMenuEntry entry}) =>
    _glassEntryHeight(context, entry: entry);

/// The vertical space one line of [style] occupies, at the reader's text scale.
/// Prego's styles set an explicit line height, so the line box is exactly the
/// scaled font size times that factor — no font-metric guesswork.
double _lineHeight(BuildContext context, {required TextStyle style}) {
  final fontSize = MediaQuery.textScalerOf(context).scale(style.fontSize!);
  return fontSize * style.height!;
}

// ── Shared entry styling, cont. ──────────────────────────────────────────────

TextStyle _labelStyle(PregoDesignSystem prego) =>
    prego.textTheme.textXs.medium.copyWith(color: prego.colors.textSecondary, letterSpacing: 0.8);

TextStyle _titleStyle(PregoDesignSystem prego, {required bool isDestructive}) =>
    prego.textTheme.textSm.medium.copyWith(
      color: isDestructive ? prego.colors.fgErrorPrimary : prego.colors.textPrimary,
    );

Color _iconColor(PregoDesignSystem prego, {required bool isDestructive}) =>
    isDestructive ? prego.colors.fgErrorPrimary : prego.colors.textSecondary;

TextStyle _subtitleStyle(PregoDesignSystem prego) =>
    prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary);

Widget _selectedCheck(PregoDesignSystem prego) =>
    Icon(Icons.check, size: 16, color: prego.colors.bgBrandSolid);
