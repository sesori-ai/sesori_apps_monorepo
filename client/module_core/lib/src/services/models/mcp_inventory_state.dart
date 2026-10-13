import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class const McpInventoryState();
final class const McpInventoryInitial() extends McpInventoryState;
final class const McpInventoryWaitingForConnection() extends McpInventoryState;
final class const McpInventoryLoading() extends McpInventoryState;
final class const McpInventoryUnrecognized() extends McpInventoryState;
final class const McpInventoryNotFound({required final NonSuccessCodeError cause}) extends McpInventoryState;
final class const McpInventoryReadFailed({required final McpInventoryUnavailable cause}) extends McpInventoryState;
final class const McpInventoryFailed({required final ApiError cause}) extends McpInventoryState;
final class const McpInventoryReady({
  required final McpInventoryResult inventory,
  required final McpInventoryRefresh refresh,
}) extends McpInventoryState;

sealed class const McpInventoryRefresh();
final class const McpInventoryRefreshIdle() extends McpInventoryRefresh;
final class const McpInventoryRefreshing() extends McpInventoryRefresh;
final class const McpInventoryRefreshOffline() extends McpInventoryRefresh;
final class const McpInventoryRefreshUnrecognized() extends McpInventoryRefresh;
final class const McpInventoryRefreshNotFound({required final NonSuccessCodeError cause}) extends McpInventoryRefresh;
final class const McpInventoryRefreshFailed({required final ApiError cause}) extends McpInventoryRefresh;

final class const McpInventoryRefreshUnavailable({required final McpInventoryUnavailable cause})
    extends McpInventoryRefresh;
