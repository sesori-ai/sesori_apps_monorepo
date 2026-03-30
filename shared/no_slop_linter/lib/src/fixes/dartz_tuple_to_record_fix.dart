import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

/// A quick fix that converts dartz Tuple types to Dart 3 records.
///
/// Converts:
/// - `Tuple2<String, int>` -> `(String, int)`
/// - `Tuple3<String, int, bool>` -> `(String, int, bool)`
/// - `Tuple2('hello', 42)` -> `('hello', 42)`
class DartzTupleToRecordFix extends ResolvedCorrectionProducer {
  DartzTupleToRecordFix({required super.context});

  static const _fixKind = FixKind(
    'no_slop_linter.fix.dartzTupleToRecord',
    DartFixKindPriority.standard,
    'Convert to Dart record',
  );

  @override
  CorrectionApplicability get applicability => CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final targetNode = node;

    if (targetNode is NamedType) {
      final typeArgs = targetNode.typeArguments;
      if (typeArgs == null) return;

      final recordType = _buildRecordType(typeArgs.arguments);
      await builder.addDartFileEdit(file, (builder) {
        builder.addSimpleReplacement(
          SourceRange(targetNode.offset, targetNode.length),
          recordType,
        );
      });
    } else if (targetNode is InstanceCreationExpression) {
      final args = targetNode.argumentList.arguments;
      if (args.isEmpty) return;

      final recordLiteral = _buildRecordLiteral(args);
      await builder.addDartFileEdit(file, (builder) {
        builder.addSimpleReplacement(
          SourceRange(targetNode.offset, targetNode.length),
          recordLiteral,
        );
      });
    }
  }

  /// Builds a record type string from type arguments.
  /// e.g., [String, int] -> "(String, int)"
  String _buildRecordType(NodeList<TypeAnnotation> typeArgs) {
    final types = typeArgs.map((t) => t.toSource()).join(', ');
    return '($types)';
  }

  /// Builds a record literal string from constructor arguments.
  /// e.g., ['hello', 42] -> "('hello', 42)"
  String _buildRecordLiteral(NodeList<Expression> args) {
    final values = args.map((a) => a.toSource()).join(', ');
    return '($values)';
  }
}
