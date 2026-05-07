import "package:flutter/material.dart";
import "package:theme_zyra/module_zyra.dart";

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
    final zyra = context.zyra;
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
            color: zyra.colors.fgSuccessPrimary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label.toString(),
              style: zyra.textTheme.textXs.medium.copyWith(
                color: zyra.colors.fgSuccessPrimary,
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
