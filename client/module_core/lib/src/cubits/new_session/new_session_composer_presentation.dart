/// What the new session page shows where the composer and its option pills
/// sit. Options never block typing: until they arrive the pills shimmer, and a
/// session created before then runs on the harness' defaults. Only a harness
/// that needs a login or a project that cannot be checked replace the composer.
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

/// Whether the project supports dedicated worktrees could not be checked.
class const NewSessionComposerProjectUnavailable() extends NewSessionComposerPresentation;
