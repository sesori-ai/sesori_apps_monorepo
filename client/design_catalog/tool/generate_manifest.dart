import "dart:convert";
import "dart:io";

import "package:sesori_design_catalog/src/catalog_manifest.dart";

void main(List<String> arguments) {
  final output = "${const JsonEncoder.withIndent("  ").convert(buildCatalogManifest())}\n";
  final file = File(catalogManifestPath);

  if (arguments.isEmpty) {
    file.writeAsStringSync(output);
    stdout.writeln("Generated ${file.path}");
    return;
  }

  if (arguments.length == 1 && arguments.single == "--check") {
    if (!file.existsSync() || file.readAsStringSync() != output) {
      stderr.writeln("$catalogManifestPath is stale. Run: dart run tool/generate_manifest.dart");
      exitCode = 1;
    }
    return;
  }

  stderr.writeln("Usage: dart run tool/generate_manifest.dart [--check]");
  exitCode = 64;
}
