import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class const McpActionResponse();
final class const McpActionReceived({required final McpEntryActionResult result}) extends McpActionResponse;
final class const McpActionRequestFailed({required final ApiError cause}) extends McpActionResponse;
