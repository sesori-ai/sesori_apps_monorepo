/// Environment variable a restart sets on the successor bridge, carrying the
/// predecessor's pid. The successor waits for that pid to exit before enforcing
/// single-live-bridge, so a restart hands off cleanly instead of prompting or
/// aborting on the still-exiting predecessor.
const String sesoriRestartPredecessorPidEnvVar = 'SESORI_RESTART_PREDECESSOR_PID';
