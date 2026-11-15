import "dart:async";

import "package:flutter/gestures.dart";
import "package:flutter/services.dart";
import "package:material_ui/material_ui.dart";

import "../components/menus/prego_anchor_menu.dart";

/// Gives an item a context menu: a long-press opens it under a finger or
/// stylus, with a light haptic and the item held sharp in [spotlight]; a
/// secondary click opens it from a mouse or trackpad, at the pointer under a
/// [PregoInteractionMode.pointer] scope. The menu is a flat [PregoAnchorMenu],
/// which owns how each mode draws it.
///
/// Both gestures win over anything inside the item that answers the same
/// press, such as a [SelectionArea]'s word selection, at any depth. The
/// long-press fires a little before Flutter's default long-press, so a nested
/// one never gets there first, and the secondary click wins as its button goes
/// down, before a selection area's own right-click selects a word and opens its
/// toolbar. A finger that moves past the touch slop before the long-press
/// fires still scrolls, drags or pinches as before, and taps still reach the
/// item.
class const PregoContextMenu({
  super.key,

  /// Builds the menu's entries as the press lands, before the open menu
  /// takes the focus (which clears a text selection inside the item).
  required final List<PregoMenuEntry> Function() entriesBuilder,
  required final double menuWidth,

  /// The sharp cut-out a long-press menu keeps around the item. A pointer
  /// menu has none.
  required final PregoMenuSpotlight spotlight,

  /// Told when the menu opens, and when it has closed, even once the item is
  /// gone.
  required final ValueChanged<bool>? onOpenChanged,

  /// Builds the item, told whether its menu is open so it can mark what the
  /// menu acts on.
  required final Widget Function(BuildContext context, bool menuOpen) builder,
}) extends StatefulWidget {
  /// A tenth of a second under [kLongPressTimeout], which a nested
  /// long-press (a selection area's) waits for.
  static const Duration longPressDuration = Duration(milliseconds: 400);

  /// The devices whose long-press opens the menu, as a selection area's
  /// long-press takes them. A held mouse button starts a drag selection
  /// instead.
  static const Set<PointerDeviceKind> _longPressDevices = {
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };

  @override
  State<PregoContextMenu> createState() => _PregoContextMenuState();
}

class _PregoContextMenuState() extends State<PregoContextMenu> {
  bool _menuOpen = false;

  /// The entries [PregoContextMenu.entriesBuilder] built for the press that
  /// opened the menu.
  List<PregoMenuEntry> _entries = const [];

  void _open({required VoidCallback openMenu}) {
    _entries = widget.entriesBuilder();
    openMenu();
  }

  @override
  Widget build(BuildContext context) => PregoAnchorMenu(
    flat: true,
    menuWidth: widget.menuWidth,
    spotlight: widget.spotlight,
    entriesBuilder: () => _entries,
    onOpenChanged: (open) {
      if (mounted) setState(() => _menuOpen = open);
      widget.onOpenChanged?.call(open);
    },
    triggerBuilder: (context, openMenu) => RawGestureDetector(
      // The semantics below offer the long-press, without merging the item's
      // own nodes into the one that carries it.
      excludeFromSemantics: true,
      gestures: {
        LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(
            debugOwner: this,
            duration: PregoContextMenu.longPressDuration,
            supportedDevices: PregoContextMenu._longPressDevices,
          ),
          (recognizer) => recognizer.onLongPress = () {
            unawaited(HapticFeedback.lightImpact());
            _open(openMenu: openMenu);
          },
        ),
        _SecondaryClickGestureRecognizer: GestureRecognizerFactoryWithHandlers<_SecondaryClickGestureRecognizer>(
          () => _SecondaryClickGestureRecognizer(debugOwner: this),
          (recognizer) => recognizer.onSecondaryClick = () => _open(openMenu: openMenu),
        ),
      },
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        onLongPress: () => _open(openMenu: openMenu),
        child: widget.builder(context, _menuOpen),
      ),
    ),
  );
}

/// Claims a secondary click as its button goes down, so nothing inside the
/// item answers it, and reports it as the button comes up if it won.
class _SecondaryClickGestureRecognizer({super.debugOwner}) extends OneSequenceGestureRecognizer {
  this : super(allowedButtonsFilter: _isSecondary);

  VoidCallback? onSecondaryClick;

  static bool _isSecondary(int buttons) => buttons == kSecondaryButton;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent) onSecondaryClick?.call();
    if (event is PointerUpEvent || event is PointerCancelEvent) stopTrackingPointer(event.pointer);
  }

  /// A menu under this one that also took the click lost it: it opens nothing.
  @override
  void rejectGesture(int pointer) => stopTrackingPointer(pointer);

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => "secondary click";
}
