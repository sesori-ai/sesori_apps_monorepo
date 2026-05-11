import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";

class UserMessageCard extends StatelessWidget {
  final MessageWithParts message;

  const UserMessageCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;
    final text = message.parts
        .where((part) => part.type == MessagePartType.text)
        .map((part) => part.text ?? "")
        .join("\n");

    return Align(
      alignment: .centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: zyra.colors.bgBrandPrimary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SelectableText(
          text,
          style: zyra.textTheme.textSm.regular.copyWith(
            color: zyra.colors.bgBrandPrimaryAlt,
          ),
        ),
      ),
    );
  }
}
