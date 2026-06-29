import "dart:async";
import "dart:math" as math;

import "package:cue/cue.dart";
import "package:flutter/material.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";

import "../../theme/prego_glass.dart";
import "../../theme/prego_theme.dart";

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

/// A tappable menu row with a [title], optional [subtitle], and an optional
/// selected check mark. Tapping runs [onTap] and dismisses the menu.
class PregoMenuItem extends PregoMenuEntry {
  const PregoMenuItem({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;
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
/// differs. See [glassEffectsEnabled] for the platform switch.
class PregoAnchorMenu extends StatefulWidget {
  const PregoAnchorMenu({
    super.key,
    required this.triggerBuilder,
    required this.entries,
    this.menuWidth = 240,
    this.menuHeight,
    this.menuBorderRadius = 24,
    this.menuScreenPadding = const EdgeInsets.all(12),
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
    return glassEffectsEnabled() ? _buildGlass(context) : _buildFlat(context);
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
      triggerBuilder: widget.triggerBuilder,
      items: [for (final entry in widget.entries) _glassEntry(context, entry)],
    );
  }

  Widget _glassEntry(BuildContext context, PregoMenuEntry entry) {
    final prego = context.prego;
    switch (entry) {
      case PregoMenuLabel(:final text):
        // GlassMenuLabel uppercases the title itself; we only supply the style.
        return GlassMenuLabel(title: text, style: _labelStyle(prego));
      case PregoMenuItem(:final title, :final subtitle, :final isSelected, :final onTap):
        return GlassMenuItem(
          title: title,
          subtitle: subtitle,
          isSelected: isSelected,
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
      // No alignment: the menu positions itself from the trigger rect so it can
      // clamp to the screen edges, mirroring GlassMenu.autoAdjustToScreen.
      triggerBuilder: (context, showModal) =>
          widget.triggerBuilder(context, () => unawaited(showModal())),
      builder: (context, triggerRect) => _FlatAnchoredMenu(
        triggerRect: triggerRect,
        entries: widget.entries,
        menuWidth: widget.menuWidth,
        menuHeight: widget.menuHeight,
        menuBorderRadius: widget.menuBorderRadius,
        screenPadding: widget.menuScreenPadding,
      ),
    );
  }
}

/// The flat (Android) menu body: a Material panel anchored to [triggerRect],
/// kept on screen by [_AnchoredMenuLayoutDelegate], and sprung in with `cue`.
class _FlatAnchoredMenu extends StatelessWidget {
  const _FlatAnchoredMenu({
    required this.triggerRect,
    required this.entries,
    required this.menuWidth,
    required this.menuHeight,
    required this.menuBorderRadius,
    required this.screenPadding,
  });

  final Rect triggerRect;
  final List<PregoMenuEntry> entries;
  final double menuWidth;
  final double? menuHeight;
  final double menuBorderRadius;
  final EdgeInsets screenPadding;

  /// Gap between the trigger and the menu it spawns.
  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final media = MediaQuery.of(context);
    final screen = media.size;
    final safe = media.padding;
    final keyboard = media.viewInsets.bottom;

    // Expand toward whichever side of the trigger has more room. For the session
    // composer (triggers near the bottom) this resolves to "expand upward".
    final spaceAbove = triggerRect.top - safe.top - screenPadding.top - _gap;
    final spaceBelow =
        screen.height - keyboard - safe.bottom - screenPadding.bottom - triggerRect.bottom - _gap;
    final expandUp = spaceAbove >= spaceBelow;
    final available = math.max(0.0, expandUp ? spaceAbove : spaceBelow);
    final maxHeight = menuHeight != null ? math.min(menuHeight!, available) : available;

    void close() => Navigator.of(context).pop();

    final panel = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(menuBorderRadius),
        boxShadow: prego.shadows.xl,
      ),
      child: Material(
        color: prego.colors.bgSecondary,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(menuBorderRadius),
          side: BorderSide(color: prego.colors.borderSecondary, width: 0.5),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final entry in entries) _flatEntry(context, entry, close)],
          ),
        ),
      ),
    );

    return CustomSingleChildLayout(
      delegate: _AnchoredMenuLayoutDelegate(
        triggerRect: triggerRect,
        menuWidth: menuWidth,
        maxHeight: maxHeight,
        expandUp: expandUp,
        screenPadding: screenPadding,
        safe: safe,
        keyboard: keyboard,
        gap: _gap,
      ),
      child: Actor(
        acts: [
          const Act.fadeIn(),
          Act.scale(from: 0.96, alignment: expandUp ? Alignment.bottomCenter : Alignment.topCenter),
          Act.slideY(from: expandUp ? 0.06 : -0.06),
        ],
        child: panel,
      ),
    );
  }

  Widget _flatEntry(BuildContext context, PregoMenuEntry entry, VoidCallback close) {
    final prego = context.prego;
    switch (entry) {
      case PregoMenuLabel(:final text):
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 4),
          // Uppercased to match GlassMenuLabel on the glass path.
          child: Text(text.toUpperCase(), style: _labelStyle(prego)),
        );
      case PregoMenuItem(:final title, :final subtitle, :final isSelected, :final onTap):
        return _FlatMenuTile(
          title: title,
          subtitle: subtitle,
          isSelected: isSelected,
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
  });

  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final subtitle = this.subtitle;
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

/// Positions the flat menu within the screen: fixed [menuWidth], capped to
/// [maxHeight], anchored above or below [triggerRect] per [expandUp], and
/// clamped so it never crosses the screen-edge padding (incl. notches and the
/// keyboard). The flat-path equivalent of `GlassMenu.autoAdjustToScreen`.
class _AnchoredMenuLayoutDelegate extends SingleChildLayoutDelegate {
  _AnchoredMenuLayoutDelegate({
    required this.triggerRect,
    required this.menuWidth,
    required this.maxHeight,
    required this.expandUp,
    required this.screenPadding,
    required this.safe,
    required this.keyboard,
    required this.gap,
  });

  final Rect triggerRect;
  final double menuWidth;
  final double maxHeight;
  final bool expandUp;
  final EdgeInsets screenPadding;
  final EdgeInsets safe;
  final double keyboard;
  final double gap;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final width = math.min(menuWidth, constraints.maxWidth);
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: math.max(0.0, math.min(maxHeight, constraints.maxHeight)),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final leftBound = screenPadding.left + safe.left;
    final rightBound = size.width - screenPadding.right - safe.right - childSize.width;
    final dx = (triggerRect.center.dx - childSize.width / 2)
        .clamp(leftBound, math.max(leftBound, rightBound))
        .toDouble();

    final topBound = screenPadding.top + safe.top;
    final bottomBound =
        size.height - keyboard - screenPadding.bottom - safe.bottom - childSize.height;
    final preferredDy =
        expandUp ? triggerRect.top - gap - childSize.height : triggerRect.bottom + gap;
    final dy = preferredDy.clamp(topBound, math.max(topBound, bottomBound)).toDouble();

    return Offset(dx, dy);
  }

  @override
  bool shouldRelayout(_AnchoredMenuLayoutDelegate oldDelegate) {
    return triggerRect != oldDelegate.triggerRect ||
        menuWidth != oldDelegate.menuWidth ||
        maxHeight != oldDelegate.maxHeight ||
        expandUp != oldDelegate.expandUp ||
        keyboard != oldDelegate.keyboard ||
        screenPadding != oldDelegate.screenPadding ||
        safe != oldDelegate.safe;
  }
}
