import "package:sesori_shared/sesori_shared.dart";

/// What the new session page shows where the composer and its option pills
/// sit. Options never block typing: until they arrive the pills shimmer, and a
/// session created before then runs on the harness' defaults. Only a harness
/// that needs a login or was held back after a refused request, or a project
/// that cannot be checked, replace the composer.
sealed class const NewSessionComposerPresentation();

/// Options are on their way; the pills shimmer at their final size.
class const NewSessionComposerPending() extends NewSessionComposerPresentation;

/// Options are on screen and selectable.
class const NewSessionComposerReady() extends NewSessionComposerPresentation;

/// Options could not be loaded; one retry control stands in for the pills.
class const NewSessionComposerRetry() extends NewSessionComposerPresentation;

/// The bridge only loads options by starting the harness, so they load when
/// asked for.
class const NewSessionComposerLoadOnDemand() extends NewSessionComposerPresentation;

/// The bridge runs no harness at all.
class const NewSessionComposerNoHarnesses() extends NewSessionComposerPresentation;

/// The selected harness needs a login before any session can start.
class const NewSessionComposerLoginRequired({
  required final String harnessName,
  required final String actionHint,
}) extends NewSessionComposerPresentation;

/// The selected harness was held back after a refused request, such as a
/// gateway rejecting its credentials, until its setup is checked again.
class const NewSessionComposerHarnessBlocked({
  required final String harnessName,
  required final PluginFailureBlock block,

  /// What to fix, as the bridge put it.
  required final String? actionHint,
}) extends NewSessionComposerPresentation;

/// Whether the project supports dedicated worktrees could not be checked.
class const NewSessionComposerProjectUnavailable() extends NewSessionComposerPresentation;
