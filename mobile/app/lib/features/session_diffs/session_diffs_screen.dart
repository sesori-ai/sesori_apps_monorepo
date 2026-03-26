import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/di/injection.dart";
import "models/diff_file_view_model.dart";
import "models/diff_view_model_builder.dart";
import "widgets/diff_file_widget.dart";
import "widgets/diff_refresh_banner.dart";

class SessionDiffsScreen extends StatelessWidget {
  final String? projectId;
  final String sessionId;

  const SessionDiffsScreen({
    super.key,
    this.projectId,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DiffCubit(
        service: getIt<SessionService>(),
        connectionService: getIt<ConnectionService>(),
        sessionId: sessionId,
      ),
      child: const SessionDiffsBody(),
    );
  }
}

/// Body widget separated from [SessionDiffsScreen] for testability.
/// Requires a [DiffCubit] in the widget tree.
class SessionDiffsBody extends StatelessWidget {
  const SessionDiffsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<DiffCubit, DiffState>(
          buildWhen: (prev, curr) => _getStats(prev) != _getStats(curr),
          builder: (context, state) {
            final (fileCount, additions, deletions) = _getStats(state);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("File Changes"),
                if (fileCount > 0)
                  Text(
                    "$fileCount file${fileCount == 1 ? '' : 's'} changed  +$additions -$deletions",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          const DiffRefreshBanner(),
          Expanded(
            child: BlocBuilder<DiffCubit, DiffState>(
              buildWhen: (prev, curr) =>
                  prev.runtimeType != curr.runtimeType ||
                  (prev is DiffStateLoaded && curr is DiffStateLoaded && !identical(prev.files, curr.files)),
              builder: (context, state) => switch (state) {
                DiffStateLoading() => const Center(child: CircularProgressIndicator()),
                DiffStateFailed(:final error) => _buildErrorState(context, error),
                DiffStateLoaded(:final files) when files.isEmpty => const Center(
                  child: Text("No file changes in this session"),
                ),
                DiffStateLoaded(:final files) => _buildFileList(files),
              },
            ),
          ),
        ],
      ),
    );
  }

  static (int fileCount, int additions, int deletions) _getStats(DiffState state) {
    return switch (state) {
      DiffStateLoaded(:final files) => (
        files.length,
        files.fold(0, (sum, f) => sum + f.additions),
        files.fold(0, (sum, f) => sum + f.deletions),
      ),
      _ => (0, 0, 0),
    };
  }

  Widget _buildFileList(List<FileDiff> files) {
    return FutureBuilder<List<DiffFileViewModel>>(
      future: DiffViewModelBuilder.build(files),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final viewModels = snapshot.data!;
        return ListView.builder(
          itemCount: viewModels.length,
          itemBuilder: (context, index) => DiffFileWidget(viewModel: viewModels[index]),
        );
      },
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Error: $error"),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.read<DiffCubit>().refresh(),
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }
}
