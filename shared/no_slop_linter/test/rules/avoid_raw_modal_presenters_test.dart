import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:no_slop_linter/src/rules/avoid_raw_modal_presenters_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidRawModalPresentersTest);
  });
}

@reflectiveTest
class AvoidRawModalPresentersTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidRawModalPresentersRule(ignoreTestFiles: false);
    newPackage('material_ui').addFile('lib/material_ui.dart', r'''
Future<T?> showDialog<T>() async => null;
Future<T?> showModalBottomSheet<T>() async => null;
''');
    newPackage('cupertino_ui').addFile('lib/cupertino_ui.dart', r'''
Future<T?> showCupertinoModalPopup<T>() async => null;
''');
    newPackage('prego').addFile('lib/prego.dart', r'''
Future<T?> showPregoModal<T>() async => null;
''');
    super.setUp();
  }

  void test_reportsSdkPresenters() async {
    final source = r'''
import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart';

void open() {
  showDialog<void>();
  showModalBottomSheet<void>();
  showCupertinoModalPopup<void>();
}
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('showDialog<'), 'showDialog'.length),
      lint(source.indexOf('showModalBottomSheet<'), 'showModalBottomSheet'.length),
      lint(source.indexOf('showCupertinoModalPopup<'), 'showCupertinoModalPopup'.length),
    ]);
  }

  void test_allowsPregoModalAndLocalNamesakes() async {
    await assertNoDiagnostics(r'''
import 'package:prego/prego.dart';

Future<T?> showDialog<T>() async => null;

void open() {
  showPregoModal<void>();
  showDialog<void>();
}
''');
  }
}
