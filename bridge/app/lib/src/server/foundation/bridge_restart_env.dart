/// Environment variable a restart sets on the successor bridge, carrying the
/// predecessor's pid. The successor waits for that pid to exit before enforcing
/// single-live-bridge, so a restart hands off cleanly instead of prompting or
/// aborting on the still-exiting predecessor.
const String sesoriRestartPredecessorPidEnvVar = 'SESORI_RESTART_PREDECESSOR_PID';

/// Marks the short-lived Windows launcher used to break the successor's
/// process ancestry before it may terminate the predecessor's full tree.
const String sesoriRestartLauncherEnvVar = 'SESORI_RESTART_LAUNCHER';
const String sesoriRestartLauncherEnvValue = '1';

/// Replaces the launch marker in the real successor without replaying the
/// inherited Windows environment through Dart's ASCII-only override map.
const String sesoriRestartLauncherConsumedEnvValue = 'consumed';
