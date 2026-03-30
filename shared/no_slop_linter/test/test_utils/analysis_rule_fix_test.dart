import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' show SourceEdit;
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test/test.dart';

typedef ProducerFactory = ResolvedCorrectionProducer Function({
  required CorrectionProducerContext context,
});

abstract class AnalysisRuleFixTest extends AnalysisRuleTest {
  /// Asserts that applying [producerFactory] to the first diagnostic from
  /// [rule] in [input] produces [expected].
  Future<void> assertHasFix(
    String input,
    String expected,
    ProducerFactory producerFactory,
  ) async {
    newFile('$testPackageLibPath/$testFileName', input);
    result = await resolveFile(
      convertPath('$testPackageLibPath/$testFileName'),
    );

    final diagnostic = result.diagnostics.firstWhere(
      (d) => d.diagnosticCode.lowerCaseName == rule.name,
      orElse: () => fail('No diagnostic found for rule "${rule.name}"'),
    );

    final libraryResult =
        await result.session.getResolvedLibrary(result.path) as ResolvedLibraryResult;

    final context = CorrectionProducerContext.createResolved(
      libraryResult: libraryResult,
      unitResult: result,
      diagnostic: diagnostic,
      selectionOffset: diagnostic.offset,
      selectionLength: diagnostic.length,
    );

    final producer = producerFactory(context: context);
    final builder = ChangeBuilder(session: result.session);
    await producer.compute(builder);

    var fixedCode = input;
    for (final fileEdit in builder.sourceChange.edits) {
      fixedCode = SourceEdit.applySequence(fixedCode, fileEdit.edits);
    }

    expect(fixedCode, expected);
  }
}
