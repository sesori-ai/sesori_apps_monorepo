import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Banner widget that displays when new changes are available via SSE.
///
/// Watches [DiffCubit] state and shows a banner with a refresh button when
/// [DiffStateLoaded.hasNewChanges] is true. The banner is hidden when false
/// or when the state is not loaded.
class DiffRefreshBanner extends StatelessWidget {
  const DiffRefreshBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiffCubit, DiffState>(
      builder: (context, state) {
        // Extract hasNewChanges from the state
        final hasNewChanges = switch (state) {
          DiffStateLoaded(:final hasNewChanges) => hasNewChanges,
          _ => false,
        };

        if (!hasNewChanges) {
          return const SizedBox.shrink();
        }

        return AnimatedSlide(
          offset: hasNewChanges ? Offset.zero : const Offset(0, -1),
          duration: const Duration(milliseconds: 200),
          child: Container(
            color: Colors.blue.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.refresh, size: 16),
                const SizedBox(width: 8),
                const Expanded(child: Text("New changes available")),
                TextButton(
                  onPressed: () => context.read<DiffCubit>().refresh(),
                  child: const Text("Refresh"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
