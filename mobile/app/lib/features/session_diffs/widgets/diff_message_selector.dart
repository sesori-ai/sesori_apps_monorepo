import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Horizontal chip row that lets the user switch between session-level diffs
/// ("All changes") and per-message diffs for each user message.
class DiffMessageSelector extends StatelessWidget {
  const DiffMessageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiffCubit, DiffState>(
      buildWhen: (prev, curr) => _extract(prev) != _extract(curr),
      builder: (context, state) {
        final (messages, selectedId) = _extract(state);

        if (messages.isEmpty) return const SizedBox.shrink();

        final userMessages = messages.where((m) => m.info.role == "user").toList();

        if (userMessages.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _buildChip(
                context,
                label: "All changes",
                isSelected: selectedId == null,
                onTap: () => context.read<DiffCubit>().selectMessage(null),
              ),
              ...userMessages.asMap().entries.map(
                (e) => _buildChip(
                  context,
                  label: "Message ${e.key + 1}",
                  isSelected: selectedId == e.value.info.id,
                  onTap: () => context.read<DiffCubit>().selectMessage(e.value.info.id),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static (List<MessageWithParts>, String?) _extract(DiffState state) {
    return switch (state) {
      DiffStateLoaded(:final messages, :final selectedMessageId) => (messages, selectedMessageId),
      _ => (const <MessageWithParts>[], null),
    };
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: isSelected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
      ),
    );
  }
}
