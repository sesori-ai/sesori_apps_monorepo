import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:no_slop_linter/src/rules/avoid_flutter_spinners_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AvoidFlutterSpinnersTest);
  });
}

@reflectiveTest
class AvoidFlutterSpinnersTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidFlutterSpinnersRule(ignoreTestFiles: false);
    newPackage('material_ui').addFile('lib/material_ui.dart', r'''
class CircularProgressIndicator {
  const CircularProgressIndicator();
  const CircularProgressIndicator.adaptive();
}
class RefreshProgressIndicator {
  const RefreshProgressIndicator();
}
class RefreshIndicator {
  const RefreshIndicator();
  const RefreshIndicator.adaptive();
  const RefreshIndicator.noSpinner();
}
''');
    newPackage('cupertino_ui').addFile('lib/cupertino_ui.dart', r'''
class CupertinoActivityIndicator {
  const CupertinoActivityIndicator();
  const CupertinoActivityIndicator.partiallyRevealed();
}
''');
    super.setUp();
  }

  void test_reportsMaterialSpinners() async {
    final source = r'''
import 'package:material_ui/material_ui.dart';

void build() {
  const CircularProgressIndicator();
  const CircularProgressIndicator.adaptive();
  const RefreshProgressIndicator();
}
''';

    await assertDiagnostics(source, [
      lint(
        source.indexOf('CircularProgressIndicator();'),
        'CircularProgressIndicator'.length,
      ),
      lint(
        source.indexOf('CircularProgressIndicator.adaptive'),
        'CircularProgressIndicator.adaptive'.length,
      ),
      lint(
        source.indexOf('RefreshProgressIndicator'),
        'RefreshProgressIndicator'.length,
      ),
    ]);
  }

  void test_reportsCupertinoSpinners() async {
    final source = r'''
import 'package:cupertino_ui/cupertino_ui.dart';

void build() {
  const CupertinoActivityIndicator();
  const CupertinoActivityIndicator.partiallyRevealed();
}
''';

    await assertDiagnostics(source, [
      lint(
        source.indexOf('CupertinoActivityIndicator();'),
        'CupertinoActivityIndicator'.length,
      ),
      lint(
        source.indexOf('CupertinoActivityIndicator.partiallyRevealed'),
        'CupertinoActivityIndicator.partiallyRevealed'.length,
      ),
    ]);
  }

  void test_reportsSpinnerProducingRefreshIndicators() async {
    final source = r'''
import 'package:material_ui/material_ui.dart';

void build() {
  const RefreshIndicator();
  const RefreshIndicator.adaptive();
}
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('RefreshIndicator();'), 'RefreshIndicator'.length),
      lint(
        source.indexOf('RefreshIndicator.adaptive'),
        'RefreshIndicator.adaptive'.length,
      ),
    ]);
  }

  void test_allowsNoSpinnerRefreshIndicator() async {
    await assertNoDiagnostics(r'''
import 'package:material_ui/material_ui.dart';

void build() {
  const RefreshIndicator.noSpinner();
}
''');
  }

  void test_reportsPrefixedConstructorTearOffs() async {
    final source = r'''
import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:material_ui/material_ui.dart' as material;

final materialSpinner = material.CircularProgressIndicator.new;
final cupertinoSpinner = cupertino.CupertinoActivityIndicator.partiallyRevealed;
final refresh = material.RefreshIndicator.noSpinner;
''';

    await assertDiagnostics(source, [
      lint(
        source.indexOf('material.CircularProgressIndicator.new'),
        'material.CircularProgressIndicator.new'.length,
      ),
      lint(
        source.indexOf('cupertino.CupertinoActivityIndicator.partiallyRevealed'),
        'cupertino.CupertinoActivityIndicator.partiallyRevealed'.length,
      ),
    ]);
  }

  void test_allowsUnrelatedClassesWithSameNames() async {
    await assertNoDiagnostics(r'''
class CircularProgressIndicator {
  const CircularProgressIndicator();
}
class CupertinoActivityIndicator {
  const CupertinoActivityIndicator();
}

void build() {
  const CircularProgressIndicator();
  const CupertinoActivityIndicator();
}
''');
  }
}
