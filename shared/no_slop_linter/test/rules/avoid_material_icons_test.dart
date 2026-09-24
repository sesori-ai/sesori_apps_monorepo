import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:no_slop_linter/src/rules/avoid_material_icons_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidMaterialIconsTest);
  });
}

@reflectiveTest
class AvoidMaterialIconsTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidMaterialIconsRule(ignoreTestFiles: false);
    newPackage('material_ui').addFile('lib/material_ui.dart', r'''
class Icons {
  static const int close = 0;
}
''');
    newPackage('theme_prego').addFile('lib/theme_prego.dart', r'''
class TablerRegular {
  static const int x = 0;
}
class Icons {
  static const int close = 0;
}
''');
    super.setUp();
  }

  void test_reportsMaterialIcons() async {
    final source = r'''
import 'package:material_ui/material_ui.dart';

const icon = Icons.close;
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('Icons.close'), 'Icons.close'.length),
    ]);
  }

  void test_reportsImportPrefixedMaterialIcons() async {
    final source = r'''
import 'package:material_ui/material_ui.dart' as material;

const icon = material.Icons.close;
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('material.Icons.close'), 'material.Icons.close'.length),
    ]);
  }

  void test_allowsTablerAndOtherIconsClasses() async {
    await assertNoDiagnostics(r'''
import 'package:theme_prego/theme_prego.dart';

const tabler = TablerRegular.x;
const other = Icons.close;
''');
  }
}
