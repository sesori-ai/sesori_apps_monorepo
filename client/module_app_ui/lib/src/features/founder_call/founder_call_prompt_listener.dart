import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../platform/external_link_opener.dart";
import "founder_call_sheet.dart";

/// Lets the screen the new connection opens settle before the sheet slides up.
const founderCallSettleDelay = Duration(milliseconds: 1200);

/// Opens the CEO call sheet on a product shell's root navigator, over whichever
/// screen is showing, whenever [FounderCallPromptCubit] asks.
class const FounderCallPromptListener({
  required final GlobalKey<NavigatorState> navigatorKey,
  required final ExternalLinkOpener openExternalLink,
  required final Widget child,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocListener<FounderCallPromptCubit, FounderCallPromptPresentation>(
      listener: (context, presentation) {
        if (presentation case FounderCallPromptShow(:final request)) {
          unawaited(
            _present(
              navigatorKey: navigatorKey,
              openExternalLink: openExternalLink,
              cubit: context.read<FounderCallPromptCubit>(),
              request: request,
            ),
          );
        }
      },
      child: child,
    );
  }
}

Future<void> _present({
  required GlobalKey<NavigatorState> navigatorKey,
  required ExternalLinkOpener openExternalLink,
  required FounderCallPromptCubit cubit,
  required FounderCallSheetRequest request,
}) async {
  // The keyboard a screen left raised closes during the delay, so the sheet
  // opens on a settled screen instead of riding the keyboard down.
  FocusManager.instance.primaryFocus?.unfocus();
  await Future<void>.delayed(founderCallSettleDelay);
  final context = navigatorKey.currentContext;
  if (context == null || !context.mounted) {
    logw("Cannot present the founder call sheet before the navigator is ready");
    return;
  }
  if (!await showFounderCallSheet(context: context, copy: request.copy)) {
    cubit.recordDeclined();
    return;
  }
  if (await openExternalLink(url: request.bookingUrl, mode: UrlLaunchMode.inAppBrowser)) {
    cubit.recordLinkOpened();
  }
}
