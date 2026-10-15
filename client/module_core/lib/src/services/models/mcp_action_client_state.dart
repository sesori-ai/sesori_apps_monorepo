import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class const McpActionClientState();
final class const McpActionsReadOnly() extends McpActionClientState;
final class const McpActionIdle() extends McpActionClientState;
final class const McpActionOffline() extends McpActionClientState;
final class const McpActionPending({required final McpEntryActionRequest request}) extends McpActionClientState;
final class const McpActionReceivedState({
  required final McpEntryActionRequest request,
  required final McpEntryActionResult result,
}) extends McpActionClientState;

/// A lost response cannot prove whether the native action was applied.
final class const McpActionUncertain({required final McpEntryActionRequest request, required final ApiError cause})
    extends McpActionClientState;
