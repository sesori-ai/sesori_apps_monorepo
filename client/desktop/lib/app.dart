import "package:flutter/material.dart";

import "features/auth_gate/auth_gate.dart";

/// Root widget of the Sesori desktop app.
///
/// Renders the sign-in gate; the real v1 window contents (status, bridge
/// on/off) arrive with the tray + window slices of Phase 2.
class SesoriDesktopApp extends StatelessWidget {
  const SesoriDesktopApp({super.key});

  static const String _appTitle = "Sesori";

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: _appTitle,
      debugShowCheckedModeBanner: false,
      home: AuthGate(),
    );
  }
}
