import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../di/injection.dart";
import "../extensions/build_context_x.dart";
import "../extensions/remote_failure_x.dart";
import "markdown_styles.dart";

/// Height the loading and failure states occupy, so the sheet opens at a
/// readable size instead of a thin strip that jumps once the document lands.
const double _placeholderHeight = 220.0;

/// Presents [document] as a bottom sheet rendering the markdown the backend
/// serves, rather than sending the user out to the web page.
Future<void> showLegalDocumentSheet(
  BuildContext context, {
  required LegalDocument document,
}) {
  final loc = context.loc;

  return showPregoBottomSheet<void>(
    context: context,
    title: switch (document) {
      LegalDocument.terms => loc.settingsLegalTerms,
      LegalDocument.privacy => loc.settingsLegalPrivacy,
    },
    builder: (_) => BlocProvider(
      create: (_) => LegalDocumentCubit(
        repository: getIt<LegalRepository>(),
        document: document,
      ),
      child: const _LegalDocumentBody(),
    ),
  );
}

class _LegalDocumentBody extends StatelessWidget {
  const _LegalDocumentBody();

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final state = context.watch<LegalDocumentCubit>().state;

    return switch (state) {
      LegalDocumentLoading() => SizedBox(
        height: _placeholderHeight,
        child: Center(
          child: PregoActivityIndicator(color: prego.colors.fgBrandPrimary),
        ),
      ),
      LegalDocumentFailed(:final reason) => _FailureView(reason: reason),
      // The sheet grows with the document and scrolls once it reaches the top
      // of the screen, so the body renders in full rather than owning a scroll
      // view of its own.
      LegalDocumentLoaded(:final markdown) => Padding(
        padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.x3l),
        child: MarkdownBody(
          data: markdown,
          onTapLink: handleMarkdownLinkTap,
          styleSheet: buildLegalMarkdownStyleSheet(prego: prego),
        ),
      ),
    };
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.reason});

  final RemoteFailureReason reason;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;

    return SizedBox(
      height: _placeholderHeight,
      child: Center(
        child: Column(
          mainAxisSize: .min,
          children: [
            Icon(
              TablerRegular.alert_circle,
              size: 32,
              color: prego.colors.fgErrorPrimary,
            ),
            const SizedBox(height: PregoSpacing.lg),
            Text(
              reason.localizedMessage(loc),
              textAlign: .center,
              style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
            ),
            const SizedBox(height: PregoSpacing.x2l),
            PregoButtonsSolid(
              label: loc.legalDocumentRetry,
              hierarchy: PregoButtonsSolidHierarchy.secondary,
              size: PregoButtonsSolidSize.md,
              leadingIcon: TablerRegular.refresh,
              onPressed: () => context.read<LegalDocumentCubit>().retry(),
            ),
          ],
        ),
      ),
    );
  }
}
