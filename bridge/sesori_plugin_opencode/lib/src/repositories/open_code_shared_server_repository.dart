import "package:http/http.dart" as http;
import "package:path/path.dart" as path;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show resolveUserHomeDirectory;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, StartAbortSignal;
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart" show SemanticRuntimeVersion;

import "../api/open_code_service_command_api.dart";
import "../api/open_code_service_registration_api.dart";
import "../models/open_code_probe_response.dart";
import "../models/open_code_service_registration.dart";
import "../runtime/open_code_runtime_policy.dart";
import "../runtime/open_code_shared_server_endpoint.dart";

/// Layer-2 discovery of OpenCode 2's shared background server.
///
/// Mirrors OpenCode's own client: read the registration file, then accept the
/// server only when `GET /api/info` answers `200` for the registered pid. Like
/// OpenCode's client it connects to whatever URL the file lists. Anything
/// unusable is logged once and reported as `null`, so the caller spawns its
/// own server instead. The command methods delegate to the OpenCode CLI.
class const OpenCodeSharedServerRepository({
  required final OpenCodeServiceRegistrationApi registrationApi,
  required final OpenCodeServiceCommandApi commandApi,
  required final http.Client Function() probeClientFactory,
}) {
  Future<SemanticRuntimeVersion> readBinaryVersion({
    required String binary,
    required Map<String, String> environment,
    required StartAbortSignal startAborted,
  }) => commandApi.readVersion(binary: binary, environment: environment, startAborted: startAborted);

  Future<bool> isServiceDisabled({
    required String binary,
    required Map<String, String> environment,
    required StartAbortSignal startAborted,
  }) => commandApi.readDisabled(binary: binary, environment: environment, startAborted: startAborted);

  Future<void> startService({
    required String binary,
    required Map<String, String> environment,
    required StartAbortSignal startAborted,
  }) => commandApi.startService(binary: binary, environment: environment, startAborted: startAborted);

  Future<OpenCodeSharedServerEndpoint?> discover({required Map<String, String> environment}) async {
    final filePath = _registrationPath(environment: environment);
    if (filePath == null) {
      Log.d("[opencode] no home or XDG_STATE_HOME; not looking for a shared OpenCode service");
      return null;
    }
    final OpenCodeServiceRegistration? registration;
    try {
      registration = await registrationApi.read(filePath: filePath);
    } on OpenCodeServiceRegistrationException catch (error) {
      _logUnusable(reason: error.message);
      return null;
    }
    if (registration == null) {
      Log.d("[opencode] no shared OpenCode service registered at $filePath");
      return null;
    }

    final uri = Uri.tryParse(registration.url);
    if (uri == null ||
        uri.scheme != "http" ||
        uri.host.isEmpty ||
        !uri.hasPort ||
        (uri.path.isNotEmpty && uri.path != "/")) {
      _logUnusable(reason: "unsupported URL ${registration.url}");
      return null;
    }
    final host = resolveOpenCodeConnectHost(bindHost: uri.host);
    final address = "${uri.host}:${uri.port}";

    final ({int statusCode, OpenCodeProbeResponse? body}) response;
    try {
      response = await probeOpenCodeInfo(
        host: host,
        port: uri.port,
        password: registration.password,
        clientFactory: probeClientFactory,
      );
    } on Object catch (error, stackTrace) {
      Log.w("[opencode] not using the shared OpenCode service: $address did not answer", error, stackTrace);
      return null;
    }
    if (response.statusCode != 200) {
      _logUnusable(reason: "$address answered HTTP ${response.statusCode}");
      return null;
    }
    final body = response.body;
    if (body == null || body.pid != registration.pid) {
      _logUnusable(reason: "$address is not the registered OpenCode process ${registration.pid}");
      return null;
    }
    final version = switch (body.version) {
      final String raw => SemanticRuntimeVersion.tryParse(value: raw),
      null => null,
    };
    if (version == null) {
      _logUnusable(reason: "$address reported no usable OpenCode version");
      return null;
    }
    if (version.version.compareTo(openCodeMinimumV2Version) < 0) {
      _logUnusable(reason: "OpenCode $version is older than $openCodeMinimumV2Version");
      return null;
    }
    return OpenCodeSharedServerEndpoint(host: host, port: uri.port, password: registration.password, version: version);
  }

  /// `<XDG_STATE_HOME or <home>/.local/state>/opencode/service.json`, exactly
  /// as OpenCode resolves it: an empty `XDG_STATE_HOME` falls back to home.
  String? _registrationPath({required Map<String, String> environment}) {
    final xdgState = environment["XDG_STATE_HOME"];
    final stateRoot = switch (xdgState) {
      final String value when value.isNotEmpty => value,
      _ => switch (resolveUserHomeDirectory(environment: environment)) {
        final String home => path.join(home, ".local", "state"),
        null => null,
      },
    };
    return stateRoot == null ? null : path.join(stateRoot, "opencode", "service.json");
  }

  void _logUnusable({required String reason}) {
    Log.w("[opencode] not using the shared OpenCode service: $reason");
  }
}
