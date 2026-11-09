import "package:flutter/services.dart" show HardwareKeyboard, LogicalKeyboardKey;
import "package:material_ui/material_ui.dart";

/// The one enter and exit a pointer shell's surfaces share: they answer at once
/// and settle quickly, and leave faster than they arrive.
const Curve pregoPointerEnterCurve = Cubic(0.23, 1, 0.32, 1);
const Duration pregoPointerEnterDuration = Duration(milliseconds: 180);
const Duration pregoPointerExitDuration = Duration(milliseconds: 130);

/// For content the app moves on its own while someone may be reading it, which
/// a fling-shaped curve would snatch from under them.
const Curve pregoContentMoveCurve = Cubic(0.3, 0.3, 0.2, 1);
const Duration pregoContentMoveDuration = Duration(milliseconds: 200);

/// Whether a key other than a modifier is held at this moment, as during a
/// shortcut or a Return press. A surface summoned that way appears at once; only
/// a click, Shift or Command held or not, gets its motion.
bool get pregoActivatedByKeyboard => HardwareKeyboard.instance.logicalKeysPressed.any(
  (key) => !_modifierKeys.contains(key),
);

final Set<LogicalKeyboardKey> _modifierKeys = {
  LogicalKeyboardKey.shiftLeft,
  LogicalKeyboardKey.shiftRight,
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
  LogicalKeyboardKey.altLeft,
  LogicalKeyboardKey.altRight,
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight,
  LogicalKeyboardKey.capsLock,
  LogicalKeyboardKey.fn,
};
