import "package:meta/meta.dart";

/// A progress event emitted while a plugin ensures its backend runtime is
/// installed and runnable (`BridgePluginDescriptor.ensureRuntime`).
///
/// The bridge core renders these for the user (a download progress bar, status
/// lines) without knowing how any particular backend is acquired. The stream's
/// FINAL event is always terminal — either [ProvisionReady] (the runtime is
/// ready, carrying the path/command to launch) or [ProvisionFailed] (acquisition
/// did not succeed; non-fatal — the bridge continues and the plugin reports a
/// degraded status). A stream that emits nothing means the plugin needs no
/// provisioning (the default).
@immutable
sealed class RuntimeProvisionProgress {
  const RuntimeProvisionProgress();
}

/// Deciding which runtime to use (explicit override vs. an OS install vs. a
/// managed download). No bytes have been fetched yet.
final class ProvisionResolving extends RuntimeProvisionProgress {
  const ProvisionResolving();

  @override
  String toString() => "ProvisionResolving";
}

/// Downloading the managed runtime archive. [receivedBytes] grows toward
/// [totalBytes]; [totalBytes] is `null` when the server did not advertise a
/// length (progress is then indeterminate).
final class ProvisionDownloading extends RuntimeProvisionProgress {
  const ProvisionDownloading({required this.receivedBytes, required this.totalBytes});

  final int receivedBytes;
  final int? totalBytes;

  /// Fraction in `[0, 1]`, or `null` when the total size is unknown.
  double? get fraction {
    final int? total = totalBytes;
    if (total == null || total <= 0) {
      return null;
    }
    return receivedBytes / total;
  }

  @override
  String toString() => "ProvisionDownloading(received: $receivedBytes, total: $totalBytes)";
}

/// Unpacking the downloaded archive into its versioned install directory.
final class ProvisionExtracting extends RuntimeProvisionProgress {
  const ProvisionExtracting();

  @override
  String toString() => "ProvisionExtracting";
}

/// Verifying the downloaded archive against its pinned checksum.
final class ProvisionVerifying extends RuntimeProvisionProgress {
  const ProvisionVerifying();

  @override
  String toString() => "ProvisionVerifying";
}

/// A non-terminal, user-facing notice surfaced mid-provision (e.g. "the
/// installed runtime is older than the minimum supported version; using the
/// managed runtime instead"). The bridge core prints [message]; it is authored
/// by the plugin so the core stays backend-agnostic.
final class ProvisionNotice extends RuntimeProvisionProgress {
  const ProvisionNotice({required this.message});

  final String message;

  @override
  String toString() => "ProvisionNotice(message: $message)";
}

/// Terminal success: the runtime is ready and [binaryPath] is the executable
/// path (or PATH-resolved command) the plugin's `start()` should launch.
final class ProvisionReady extends RuntimeProvisionProgress {
  const ProvisionReady({required this.binaryPath});

  final String binaryPath;

  @override
  String toString() => "ProvisionReady(binaryPath: $binaryPath)";
}

/// Terminal failure: the runtime could not be provisioned. Non-fatal — the
/// bridge continues to `start()`, which surfaces a degraded plugin status.
/// [message] explains what went wrong for logs/diagnostics.
final class ProvisionFailed extends RuntimeProvisionProgress {
  const ProvisionFailed({required this.message});

  final String message;

  @override
  String toString() => "ProvisionFailed(message: $message)";
}
