import "package:meta/meta.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../composer/unsent_composer.dart";

/// The composing route's composer as the session it created takes it over, so
/// the session screen can build the same composer before its first load: the
/// options the launch committed at Send, what the composer could do, and what
/// it still held.
@immutable
final class const SessionLaunchComposer({
  required final List<AgentInfo> agents,
  required final String? agent,
  required final List<ProviderInfo> providers,
  required final AgentModel? agentModel,
  required final List<SessionVariant> availableVariants,
  required final List<CommandInfo> commands,

  /// Whether the launch runs in fast mode, already resolved against [agentModel].
  required final bool fastMode,
  required final bool supportsPromptAttachments,

  /// Whether the composer had keyboard focus, so the session screen's composer
  /// takes it back on its first frame and the keyboard never drops.
  required final bool hadFocus,

  /// Null when the composer held nothing unsent.
  required final UnsentComposer? unsent,
});
