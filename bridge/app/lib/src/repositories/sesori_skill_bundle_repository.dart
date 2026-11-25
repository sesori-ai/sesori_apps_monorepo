import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show SesoriSkillBundle;
import "package:sesori_tool_interface/sesori_tool_interface.dart" show SesoriToolGuide;

import "../api/sesori_skill_bundle_storage.dart";

/// The skill bundle harness launches load, kept in step with the folder.
class SesoriSkillBundleRepository({required final SesoriSkillBundleStorage _storage}) {
  SesoriSkillBundle? _current;

  /// The bundle the last [write] produced, or null before the first one, after
  /// one with no guides, or after one that failed.
  SesoriSkillBundle? get current => _current;

  void write({required List<SesoriToolGuide> guides}) {
    _current = null;
    _current = _storage.write(guides: guides);
  }
}
