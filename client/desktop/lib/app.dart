import "package:flutter/material.dart";

/// Root widget of the Sesori desktop app.
///
/// Placeholder window only: the real v1 window contents (status, login,
/// bridge on/off) arrive with the tray + window slices of Phase 2.
class SesoriDesktopApp extends StatelessWidget {
  const SesoriDesktopApp({super.key});

  static const String _appTitle = "Sesori";

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: _appTitle,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(_appTitle),
        ),
      ),
    );
  }
}
