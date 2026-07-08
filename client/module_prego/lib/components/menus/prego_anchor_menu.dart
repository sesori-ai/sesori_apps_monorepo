import "dart:async";

import "package:cue/cue.dart";
import "package:flutter/material.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";

import "../../theme/prego_glass.dart";
import "../../theme/prego_theme.dart";
import "anchored_flat_panel.dart";

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
  });

  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  /// Optional glyph shown before the title. Rendered identically on the glass
  /// and flat paths (muted to the secondary text colour).
  final IconData? leadingIcon;
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

/// A popup menu that anchors to its trigger, rendered platform-appropriately.
///
/// On Apple platforms it is the `liquid_glass_widgets` [GlassMenu] — the
/// iOS-26 liquid-glass popup that morphs out of the trigger. On Android, where
/// the glass shader + backdrop blur jank, it falls back to a flat Material panel
/// anchored to the trigger and animated with the `cue` package's spring physics
/// (a [CueModalTransition]) — same anchored-popup behaviour, zero shader cost.
///
/// The same [entries] and [triggerBuilder] drive both paths; only the rendering
/// differs. See [glassEffectsEnabled] for the platform switch. Set [flat] to
/// force the flat/`cue` path on every platform (including Apple) — for a menu
/// paired with a flat trigger, where a glass popup would look out of place.
class PregoAnchorMenu extends StatefulWidget {
  const PregoAnchorMenu({
    super.key,
    required this.triggerBuilder,
    required this.entries,
    this.menuWidth = 240,
    this.menuHeight,
    this.menuBorderRadius = 24,
    this.menuScreenPadding = const EdgeInsets.all(12),
    this.flat = false,
  });

  /// Builds the tappable trigger. The provided callback opens the menu.
  final PregoMenuTriggerBuilder triggerBuilder;

  /// The menu contents, top to bottom.
  final List<PregoMenuEntry> entries;

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
      items: [for (final entry in widget.entries) _glassEntry(context, entry: entry)],
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
      case PregoMenuItem(:final title, :final subtitle, :final isSelected, :final onTap, :final leadingIcon):
        return GlassMenuItem(
          title: title,
          subtitle: subtitle,
          isSelected: isSelected,
          icon: leadingIcon == null ? null : Icon(leadingIcon, size: 20, color: prego.colors.textSecondary),
          titleStyle: _titleStyle(prego),
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
    return CueModalTransition(
      barrierColor: Colors.transparent,
      motion: const Spring.smooth(),
      reverseMotion: const Spring.snappy(),
      // No alignment: the panel positions itself from the trigger rect so it can
      // clamp to the screen edges, mirroring GlassMenu.autoAdjustToScreen.
      triggerBuilder: (context, showModal) =>
          widget.triggerBuilder(context, () => unawaited(showModal())),
      builder: (context, triggerRect) => AnchoredFlatPanel(
        triggerRect: triggerRect,
        width: widget.menuWidth,
        height: widget.menuHeight,
        borderRadius: widget.menuBorderRadius,
        screenPadding: widget.menuScreenPadding,
        childBuilder: (context, close) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final entry in widget.entries) _flatEntry(context, entry: entry, close: close),
            ],
          ),
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
      case PregoMenuItem(:final title, :final subtitle, :final isSelected, :final onTap, :final leadingIcon):
        return _FlatMenuTile(
          title: title,
          subtitle: subtitle,
          isSelected: isSelected,
          leadingIcon: leadingIcon,
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
    this.leadingIcon,
  });

  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;
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
                Icon(leadingIcon, size: 20, color: prego.colors.textSecondary),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _titleStyle(prego)),
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

TextStyle _titleStyle(PregoDesignSystem prego) =>
    prego.textTheme.textSm.medium.copyWith(color: prego.colors.textPrimary);

TextStyle _subtitleStyle(PregoDesignSystem prego) =>
    prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary);

Widget _selectedCheck(PregoDesignSystem prego) =>
    Icon(Icons.check, size: 16, color: prego.colors.bgBrandSolid);
