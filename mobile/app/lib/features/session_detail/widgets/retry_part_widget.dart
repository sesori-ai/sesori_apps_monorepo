import "package:flutter/material.dart";

class RetryPartWidget extends StatelessWidget {
  final int? attempt;
  final String? retryError;

  const RetryPartWidget({
    super.key,
    required this.attempt,
    required this.retryError,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = StringBuffer("Retry");
    if (attempt != null) {
      label.write(" #$attempt");
    }
    if (retryError != null) {
      label.write(": $retryError");
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.refresh,
            size: 14,
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label.toString(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.tertiary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
