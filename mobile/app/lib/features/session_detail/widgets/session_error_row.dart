import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Inline error row displayed in the session chat.
///
/// Center-aligned, red text, no bubble — distinct from user/agent messages.
/// Persistent (not dismissible) and part of chat history.
class SessionErrorRow extends StatelessWidget {
  final SessionError error;

  const SessionErrorRow({
    super.key,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Center(
        child: Text(
          error.message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
