import "package:flutter/services.dart" show LogicalKeyboardKey;
import "package:material_ui/material_ui.dart";

/// Desktop Escape policy applied above the root navigator.
///
/// Escape first relinquishes active text editing. Otherwise it dismisses only
/// a popup route (dialog, menu, or bottom sheet); ordinary cockpit pages never
/// become an implicit back shortcut. A closer shortcut, such as the image
/// viewer's own Escape handler, wins before this ancestor callback.
class const DesktopEscapeDismissal({super.key, required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): _handleEscape,
      },
      child: child,
    );
  }

  void _handleEscape() {
    final focus = FocusManager.instance.primaryFocus;
    final focusContext = focus?.context;
    if (focusContext == null) {
      return;
    }
    final editing =
        focusContext.widget is EditableText || focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
    if (editing) {
      focus?.unfocus();
      return;
    }

    final route = ModalRoute.of(focusContext);
    final navigator = route?.navigator;
    if (route != null && _isPopupRoute(route: route) && route.isCurrent && navigator != null) {
      navigator.maybePop();
    }
  }
}

bool _isPopupRoute<T>({required Route<T> route}) => route is PopupRoute<T>;
