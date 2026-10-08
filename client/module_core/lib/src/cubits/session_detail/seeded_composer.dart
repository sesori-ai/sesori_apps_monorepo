import "package:meta/meta.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../foundation/models/session_launch/session_launch_composer.dart";

/// The launch's composer as the session screen builds it before its first
/// load, with the command staged in it since.
@immutable
final class const SeededComposer({
  required final SessionLaunchComposer composer,
  required final CommandInfo? stagedCommand,
});
