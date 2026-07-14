import "dart:async";

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
  const PregoMenuCustom({required this.builder});

  final Widget Function(BuildContext context, VoidCallback close) builder;
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
  Rect resolveRect({required Rect triggerRect}) => inset.deflateRect(triggerRect);

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
    this.menuHeight,
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

  /// Optional fixed maximum height. When set, the menu caps at this height and
  /// scrolls internally; when null it sizes to its content (still bounded to
  /// stay on screen).
  final double? menuHeight;

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
    return GlassMenu(
      controller: _glassController,
      menuWidth: widget.menuWidth,
      menuHeight: widget.menuHeight,
      menuBorderRadius: widget.menuBorderRadius,
      autoAdjustToScreen: true,
      menuPadding: widget.menuScreenPadding,
      settings: LiquidGlassSettings(glassColor: context.prego.colors.buttonGlassPrimaryBackground),
      triggerBuilder: (context, toggle) => widget.triggerBuilder(context, () {
        toggle();
        _alignGlassMenuToTrigger(context);
      }),
      items: [for (final entry in widget.entriesBuilder()) _glassEntry(context, entry: entry)],
    );
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
        return GlassMenuLabel(title: text, style: _labelStyle(prego));
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
        return const GlassMenuDivider();
      case PregoMenuCustom(:final builder):
        return builder(context, _glassController.close);
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
    return AnchoredFlatPanel(
      triggerRect: triggerRect,
      width: widget.menuWidth,
      height: widget.menuHeight,
      borderRadius: widget.menuBorderRadius,
      screenPadding: widget.menuScreenPadding,
      // AnchoredFlatPanel owns the scroll, so this supplies just the padded
      // column of entries; the panel scrolls it when the menu is taller than
      // the room beside the trigger.
      childBuilder: (context, close) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in widget.entriesBuilder()) _flatEntry(context, entry: entry, close: close),
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
      borderRadius: BorderRadius.circular(16),
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
