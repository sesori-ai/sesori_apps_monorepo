import "dart:convert";
import "dart:io" as io;

import "package:path/path.dart" as path;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

const String openCodeDeviceCanvasToolPluginFileName = "sesori-device-canvas-tools.js";
const String _openCodeDeviceCanvasToolConfigFileName = "sesori-device-canvas-tools.json";

const String _pluginSourceTemplate = r'''
import { readFile, unlink, writeFile } from "node:fs/promises"

const bootstrapFileEnvironment = "@@BOOTSTRAP_FILE_ENV@@"
const rendezvousEnvironment = "@@RENDEZVOUS_ENV@@"
const readyFileEnvironment = "@@READY_FILE_ENV@@"
const protocolVersion = @@PROTOCOL_VERSION@@
const bootstrapFilePath = process.env[bootstrapFileEnvironment]?.trim()
const rendezvousPath = process.env[rendezvousEnvironment]?.trim()
const readyFilePath = process.env[readyFileEnvironment]?.trim()

delete process.env[bootstrapFileEnvironment]
delete process.env[rendezvousEnvironment]
delete process.env[readyFileEnvironment]

let bootstrapSecret
let bearerToken
let registrationPromise

function unavailable() {
  return JSON.stringify({ outcome: "bridgeUnavailable" })
}

async function request(url, init, abortSignal) {
  const controller = new AbortController()
  const abort = () => controller.abort()
  if (abortSignal?.aborted) controller.abort()
  else abortSignal?.addEventListener("abort", abort, { once: true })
  const timeout = setTimeout(() => controller.abort(), 5000)
  try {
    return await fetch(url, { ...init, redirect: "error", signal: controller.signal })
  } finally {
    clearTimeout(timeout)
    abortSignal?.removeEventListener("abort", abort)
  }
}

async function baseUrl() {
  if (!rendezvousPath) throw new Error("missing rendezvous")
  const rendezvous = JSON.parse(await readFile(rendezvousPath, "utf8"))
  if (rendezvous.protocolVersion !== protocolVersion) throw new Error("unsupported protocol")
  if (!Number.isInteger(rendezvous.port) || rendezvous.port < 1 || rendezvous.port > 65535) {
    throw new Error("invalid rendezvous")
  }
  return `http://127.0.0.1:${rendezvous.port}`
}

async function readBootstrapSecret() {
  if (bootstrapSecret) return bootstrapSecret
  if (!bootstrapFilePath) throw new Error("missing bootstrap credential")
  const secret = (await readFile(bootstrapFilePath, "utf8")).trim()
  if (!secret) throw new Error("empty bootstrap credential")
  await unlink(bootstrapFilePath)
  bootstrapSecret = secret
  return bootstrapSecret
}

async function register(endpoint) {
  if (bearerToken) return bearerToken
  const secret = await readBootstrapSecret()
  const response = await request(`${endpoint}/register`, {
    method: "POST",
    headers: { Authorization: `Bearer ${secret}` },
  })
  if (!response.ok) throw new Error("registration rejected")
  const body = await response.json()
  if (typeof body?.bearerToken !== "string" || body.bearerToken.length < 32) {
    throw new Error("invalid registration response")
  }
  bearerToken = body.bearerToken
  return bearerToken
}

async function ensureBearerToken(endpoint) {
  if (bearerToken) return bearerToken
  registrationPromise ??= register(endpoint).finally(() => {
    registrationPromise = undefined
  })
  return await registrationPromise
}

async function invoke(route, body, abortSignal, retry = true) {
  try {
    const endpoint = await baseUrl()
    const token = await ensureBearerToken(endpoint)
    const response = await request(`${endpoint}/${route}`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    }, abortSignal)
    if (response.status === 401 && retry) {
      if (bearerToken === token) bearerToken = undefined
      return await invoke(route, body, abortSignal, false)
    }
    const result = await response.json()
    if (typeof result?.outcome !== "string") return unavailable()
    return JSON.stringify(result)
  } catch {
    return unavailable()
  }
}

export const SesoriDeviceCanvasTools = async () => {
  if (!readyFilePath) throw new Error("missing ready-file path")
  await ensureBearerToken(await baseUrl())
  await writeFile(readyFilePath, "ready")

  return {
    "shell.env": async (_input, output) => {
      delete output.env[bootstrapFileEnvironment]
      delete output.env[rendezvousEnvironment]
      delete output.env[readyFileEnvironment]
    },
    tool: {
      list_simulators: {
        description:
          "List online iOS simulators and Android emulators in Device Canvas, including whether each is unclaimed, owned by this session, or owned by another session.",
        args: {},
        async execute(_args, context) {
          return await invoke("list", { backendSessionId: context.sessionID }, context.abort)
        },
      },
      claim_simulator: {
        description:
          "Claim one online Device Canvas simulator for this OpenCode session. A device owned by another session is never reassigned.",
        args: {
          deviceKey: {
            type: "string",
            minLength: 1,
            maxLength: 512,
            description: "Device key returned by list_simulators",
          },
        },
        async execute(args, context) {
          return await invoke("claim", { backendSessionId: context.sessionID, deviceKey: args.deviceKey }, context.abort)
        },
      },
      release_simulator: {
        description: "Release a Device Canvas simulator owned by this OpenCode session.",
        args: {
          deviceKey: {
            type: "string",
            minLength: 1,
            maxLength: 512,
            description: "Device key returned by list_simulators",
          },
        },
        async execute(args, context) {
          return await invoke("release", { backendSessionId: context.sessionID, deviceKey: args.deviceKey }, context.abort)
        },
      },
    },
  }
}
''';

String buildOpenCodeDeviceCanvasToolPluginSource() {
  return _pluginSourceTemplate
      .replaceAll("@@BOOTSTRAP_FILE_ENV@@", deviceCanvasAgentToolBootstrapFileEnvironment)
      .replaceAll("@@RENDEZVOUS_ENV@@", deviceCanvasAgentToolRendezvousEnvironment)
      .replaceAll("@@READY_FILE_ENV@@", deviceCanvasAgentToolReadyFileEnvironment)
      .replaceAll("@@PROTOCOL_VERSION@@", "$deviceCanvasAgentToolProtocolVersion");
}

/// Installs the bridge-owned native OpenCode tools without touching user or
/// project configuration. The returned environment is applied only to the
/// managed OpenCode process.
Future<Map<String, String>> configureOpenCodeDeviceCanvasTools({required PluginHost host}) async {
  final bootstrapSecret = host.environment[deviceCanvasAgentToolBootstrapSecretEnvironment]?.trim();
  final rendezvousPath = host.environment[deviceCanvasAgentToolRendezvousEnvironment]?.trim();
  if (bootstrapSecret == null || bootstrapSecret.isEmpty || rendezvousPath == null || rendezvousPath.isEmpty) {
    return const <String, String>{};
  }

  final hasInlineConfig = host.environment["OPENCODE_CONFIG_CONTENT"]?.trim().isNotEmpty ?? false;
  final hasCustomConfig = host.environment["OPENCODE_CONFIG"]?.trim().isNotEmpty ?? false;
  if (hasInlineConfig && hasCustomConfig) {
    Log.w(
      "[opencode] Device Canvas tools are unavailable because both OPENCODE_CONFIG and "
      "OPENCODE_CONFIG_CONTENT are already set",
    );
    return const <String, String>{};
  }

  try {
    final bootstrapFilePath = path.join(host.stateDirectory, "sesori-device-canvas-tools.bootstrap");
    final readyFilePath = path.join(host.stateDirectory, "sesori-device-canvas-tools.ready");
    final readyFile = io.File(readyFilePath);
    if (readyFile.existsSync()) readyFile.deleteSync();
    await host.store.write(
      name: openCodeDeviceCanvasToolPluginFileName,
      contents: buildOpenCodeDeviceCanvasToolPluginSource(),
    );
    final pluginPath = path.join(host.stateDirectory, openCodeDeviceCanvasToolPluginFileName);
    final pluginConfig = jsonEncode(<String, Object>{
      "plugin": <String>[Uri.file(pluginPath, windows: io.Platform.isWindows).toString()],
    });

    if (!hasInlineConfig) {
      return <String, String>{
        deviceCanvasAgentToolBootstrapSecretEnvironment: bootstrapSecret,
        deviceCanvasAgentToolBootstrapFileEnvironment: bootstrapFilePath,
        deviceCanvasAgentToolRendezvousEnvironment: rendezvousPath,
        deviceCanvasAgentToolReadyFileEnvironment: readyFilePath,
        "OPENCODE_CONFIG_CONTENT": pluginConfig,
      };
    }

    await host.store.write(name: _openCodeDeviceCanvasToolConfigFileName, contents: pluginConfig);
    return <String, String>{
      deviceCanvasAgentToolBootstrapSecretEnvironment: bootstrapSecret,
      deviceCanvasAgentToolBootstrapFileEnvironment: bootstrapFilePath,
      deviceCanvasAgentToolRendezvousEnvironment: rendezvousPath,
      deviceCanvasAgentToolReadyFileEnvironment: readyFilePath,
      "OPENCODE_CONFIG": path.join(host.stateDirectory, _openCodeDeviceCanvasToolConfigFileName),
    };
  } on Object catch (error, stackTrace) {
    Log.w("[opencode] failed to prepare Device Canvas tools", error, stackTrace);
    return const <String, String>{};
  }
}
