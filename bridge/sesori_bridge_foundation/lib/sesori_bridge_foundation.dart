/// Shared Layer-0 foundation primitives for the bridge — reusable by the main
/// bridge app and by plugins alike (not plugin-only). Transport/process/value
/// building blocks with no business logic.
library;

export "src/archive_extractor.dart";
export "src/binary_download_client.dart";
export "src/checksum_validator.dart";
export "src/command_executor.dart";
export "src/host_process_command_executor.dart";
export "src/platform_target.dart";
export "src/semantic_version.dart";
