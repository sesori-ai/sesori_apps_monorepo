import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class const McpAuthenticationResponse();

final class const McpAuthenticationReceived({required final McpAuthenticationResult result})
    extends McpAuthenticationResponse;

final class const McpAuthenticationRouteMissing({required final NonSuccessCodeError cause})
    extends McpAuthenticationResponse;

final class const McpAuthenticationRequestFailed({required final ApiError cause}) extends McpAuthenticationResponse;
