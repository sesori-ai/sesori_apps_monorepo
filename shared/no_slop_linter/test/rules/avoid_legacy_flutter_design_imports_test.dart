import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:no_slop_linter/src/rules/avoid_legacy_flutter_design_imports_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidLegacyFlutterDesignImportsTest);
  });
}

@reflectiveTest
class AvoidLegacyFlutterDesignImportsTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidLegacyFlutterDesignImportsRule(ignoreTestFiles: false);
    newPackage('flutter')
      ..addFile('lib/material.dart', 'class MaterialMarker {}')
      ..addFile('lib/cupertino.dart', 'class CupertinoMarker {}')
      ..addFile('lib/foundation.dart', 'class FoundationMarker {}');
    newPackage('material_ui').addFile('lib/material_ui.dart', 'class MaterialMarker {}');
    newPackage('cupertino_ui').addFile('lib/cupertino_ui.dart', 'class CupertinoMarker {}');
    super.setUp();
  }

  void test_reportsLegacyMaterialImport() async {
    await assertDiagnostics(
      '''
import 'package:flutter/material.dart';
MaterialMarker? marker;
''',
      [lint(7, 31)],
    );
  }

  void test_reportsLegacyCupertinoImport() async {
    await assertDiagnostics(
      '''
import 'package:flutter/cupertino.dart';
CupertinoMarker? marker;
''',
      [lint(7, 32)],
    );
  }

  void test_allowsStandaloneDesignImports() async {
    await assertNoDiagnostics('''
import 'package:material_ui/material_ui.dart' as material;
import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
material.MaterialMarker? materialMarker;
cupertino.CupertinoMarker? cupertinoMarker;
''');
  }

  void test_allowsFlutterFoundationImport() async {
    await assertNoDiagnostics('''
import 'package:flutter/foundation.dart';
FoundationMarker? marker;
''');
  }
}
