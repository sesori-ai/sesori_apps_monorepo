import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class const McpReadResult();
final class const McpReadUnrecognized() extends McpReadResult;
final class const McpReadSuccess({required final McpInventoryResult inventory}) extends McpReadResult;
final class const McpReadNotFound({required final NonSuccessCodeError cause}) extends McpReadResult;
final class const McpReadInventoryFailed({required final McpInventoryUnavailable cause}) extends McpReadResult;
final class const McpReadFailed({required final ApiError cause}) extends McpReadResult;
