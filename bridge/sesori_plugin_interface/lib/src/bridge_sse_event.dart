import "models/plugin_agent.dart";
import "models/plugin_message.dart";
import "models/plugin_pending_question.dart";
import "models/plugin_queued_prompt.dart";
import "models/plugin_session_status.dart";

sealed class const BridgeSseEvent();

/// Mapping provenance for reconciliation synthesized during a forced stop.
///
/// This wrapper carries no stop-fence authority. The generation runtime owns
/// that authorization separately, so a plugin-emitted wrapper remains an
/// ordinary fenced event.
class const BridgeSseTerminalHandoff({required final BridgeSseEvent event}) extends BridgeSseEvent;

class const BridgeSseServerConnected() extends BridgeSseEvent;

class const BridgeSseServerHeartbeat() extends BridgeSseEvent;

class const BridgeSseServerInstanceDisposed({final String? directory}) extends BridgeSseEvent;

class const BridgeSseGlobalDisposed() extends BridgeSseEvent;

/// Signals that the emitting plugin's process-wide command catalog changed.
class const BridgeSseCommandCatalogUpdated() extends BridgeSseEvent;

// ignore: no_slop_linter/prefer_specific_type, SSE payload values are heterogeneous
class const BridgeSseSessionCreated({required final Map<String, dynamic> info}) extends BridgeSseEvent;

// ignore: no_slop_linter/prefer_specific_type, SSE payload values are heterogeneous
class const BridgeSseSessionUpdated({required final Map<String, dynamic> info, required final bool titleChanged})
    extends BridgeSseEvent;

/// Signals that session-creation options changed for a backend session.
///
/// This is an internal plugin event. [sessionID] is the backend's session
/// identity so bridge core can resolve its stable persisted binding.
class const BridgeSseSessionOptionsChanged({required final String sessionID}) extends BridgeSseEvent;

/// Signals that a backend changed the effective defaults for future turns.
class const BridgeSseSessionPromptDefaultsChanged({
  required final String sessionID,
  required final String? agent,
  required final PluginAgentModel? model,
}) extends BridgeSseEvent;

// ignore: no_slop_linter/prefer_specific_type, SSE payload values are heterogeneous
class const BridgeSseSessionDeleted({required final Map<String, dynamic> info}) extends BridgeSseEvent;

class const BridgeSseSessionDiff({required final String sessionID}) extends BridgeSseEvent;

class const BridgeSseSessionError({required final String? sessionID}) extends BridgeSseEvent;

class const BridgeSseSessionCompacted({required final String sessionID}) extends BridgeSseEvent;

class const BridgeSseSessionStatus({required final String sessionID, required final PluginSessionStatus status})
    extends BridgeSseEvent;

class const BridgeSseSessionIdle({required final String sessionID}) extends BridgeSseEvent;

class const BridgeSseCommandExecuted({
  required final String name,
  required final String sessionID,
  required final String arguments,
  required final String messageID,
}) extends BridgeSseEvent;

/// Full replacement of [sessionID]'s queued-prompt list.
///
/// Emitted by queue-owning plugins on every change (accept, cancel, dispatch,
/// abort, failure) with the complete current list, so a missed event
/// self-heals on the next one. [sessionID] is the backend session identity;
/// bridge core translates it to the stable binding before relaying.
class const BridgeSseQueuedPromptsUpdated({
  required final String sessionID,
  required final List<PluginQueuedPrompt> prompts,
}) extends BridgeSseEvent;

class const BridgeSseMessageUpdated({required final PluginMessage info}) extends BridgeSseEvent;

class const BridgeSseMessageRemoved({required final String sessionID, required final String messageID})
    extends BridgeSseEvent;

class const BridgeSseMessagePartUpdated({required final PluginMessagePart part}) extends BridgeSseEvent;

class const BridgeSseMessagePartDelta({
  required final String sessionID,
  required final String messageID,
  required final String partID,
  required final String field,
  required final String delta,
}) extends BridgeSseEvent;

class const BridgeSseMessagePartRemoved({
  required final String sessionID,
  required final String messageID,
  required final String partID,
}) extends BridgeSseEvent;

class const BridgeSsePermissionAsked({
  required final String requestID,
  required final String sessionID,

  /// Top-most root session this request should be surfaced under (for a
  /// child/sub-agent session's request). Null when unknown.
  required final String? displaySessionId,
  required final String tool,
  required final String description,
  required final bool allowAlways,
}) extends BridgeSseEvent;

class const BridgeSsePermissionReplied({
  required final String requestID,
  required final String sessionID,

  /// Root session this request is surfaced under. Null when unknown.
  required final String? displaySessionId,
  required final String reply,
}) extends BridgeSseEvent;

class const BridgeSsePermissionUpdated() extends BridgeSseEvent;

class const BridgeSseQuestionAsked({
  required final String id,
  required final String sessionID,

  /// Top-most root session this request should be surfaced under (for a
  /// child/sub-agent session's request). Null when unknown.
  required final String? displaySessionId,
  required final List<PluginQuestionInfo> questions,
}) extends BridgeSseEvent;

class const BridgeSseQuestionReplied({
  required final String requestID,
  required final String sessionID,

  /// Root session this request is surfaced under. Null when unknown.
  required final String? displaySessionId,
}) extends BridgeSseEvent;

class const BridgeSseQuestionRejected({
  required final String requestID,
  required final String sessionID,

  /// Root session this request is surfaced under. Null when unknown.
  required final String? displaySessionId,
}) extends BridgeSseEvent;

class const BridgeSseTodoUpdated({required final String sessionID}) extends BridgeSseEvent;

class const BridgeSseProjectUpdated() extends BridgeSseEvent;

class const BridgeSseVcsBranchUpdated() extends BridgeSseEvent;

class const BridgeSseFileEdited({final String? file}) extends BridgeSseEvent;

/// OpenCode reports a newer version of itself; the bridge pushes it as an
/// immediate installation-update notification.
class const BridgeSseInstallationUpdateAvailable({final String? version}) extends BridgeSseEvent;

/// Transient backend guidance. [sessionID] is the backend session identity
/// before bridge-core remapping; null means genuinely global or unattributed.
class const BridgeSseTuiToastShow({
  required final String? sessionID,
  required final String? title,
  required final String? message,
  required final String? variant,
}) extends BridgeSseEvent;
