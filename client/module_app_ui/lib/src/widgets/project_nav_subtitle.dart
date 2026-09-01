import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";

/// The repo's brand glyph. GitHub keeps the mock's filled glyph; the solid
/// Tabler set carries no other git-forge brands, so GitLab/Bitbucket use their
/// regular-weight glyphs and unrecognised hosts fall back to the generic git
/// mark.
IconData _providerIcon({required RepoProvider provider}) => switch (provider) {
  RepoProvider.github => TablerSolid.brand_github,
  RepoProvider.gitlab => TablerRegular.brand_gitlab,
  RepoProvider.bitbucket => TablerRegular.brand_bitbucket,
  RepoProvider.other => TablerRegular.brand_git,
};

/// The second line of the top bar on every screen inside a project: the
/// repository slug of the project's git remote, with a dot for whether the
/// relay↔bridge chain is up.
///
/// Returns null when there is no slug to show — old bridges and remote-less
/// projects never deliver one — so the bar renders its title alone rather than
/// reserving an empty line. While the first load is in flight it shimmers the
/// list body's loading treatment instead.
///
/// Reads the project's [SessionListCubit], so it only works below the sessions
/// shell; the caller's element is what rebuilds when either cubit emits.
Widget? buildProjectNavSubtitle(BuildContext context) {
  final loc = context.loc;
  final state = context.watch<SessionListCubit>().state;
  // Green only while the relay↔bridge chain is fully connected — a hidden
  // banner alone is not enough, since disconnected and unregistered
  // bridge-offline parks are bannerless too.
  final overlay = context.watch<ConnectionOverlayCubit>().state;
  final online = overlay is ConnectionOverlayHidden && overlay.connected;

  return switch (state) {
    SessionListLoading() => const PregoNavSubtitleSkeleton(),
    SessionListLoaded(repoSlug: final repoSlug?, :final repoProvider) => PregoNavSubtitle(
      text: repoSlug,
      icon: _providerIcon(provider: repoProvider),
      status: online ? PregoNavStatus.online : PregoNavStatus.offline,
      infoMessage: repoSlug,
      infoSemanticLabel: loc.sessionListRepoInfoSemantics,
    ),
    SessionListLoaded() || SessionListFailed() => null,
  };
}
