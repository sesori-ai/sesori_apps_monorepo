import "package:sesori_shared/sesori_shared.dart";

sealed class const McpControlResult();

final class const McpControlCompleted() extends McpControlResult;

final class const McpControlUnavailable({required final McpActionUnavailableReason reason}) extends McpControlResult;

final class const McpControlFailed() extends McpControlResult;
