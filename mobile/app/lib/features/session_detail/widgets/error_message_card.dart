import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Inline error display for a [MessageError].
///
/// Renders as a center-aligned red text row with no bubble, distinct
/// from regular assistant/user messages.
class ErrorMessageCard extends StatelessWidget {
  final MessageError message;

  const ErrorMessageCard({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: Text(
          message.errorMessage,
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
