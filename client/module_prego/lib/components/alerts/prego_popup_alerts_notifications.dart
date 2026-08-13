import "dart:async";

import "package:material_ui/material_ui.dart";

import "../../icons/tabler_icons.g.dart";
import "../../interactions/prego_tappable.dart";
import "../../theme/prego_theme.dart";
import "../buttons/prego_buttons_solid.dart";
import "../navigation/prego_top_bar_inset.dart";

/// Visual variant for [PregoPopupAlertsNotifications].
enum PregoPopupAlertsNotificationsVariant() {
  info,
  success,
  warning,
  error,
  loading,
}

/// Configuration for an alert action.
class const PregoPopupAlertsNotificationsAction({
  required final String label,
  required final VoidCallback onPressed,
});

/// Optional supporting content for an alert presented by
/// [PregoPopupAlertPresenter].
class const PregoPopupAlertContent({
  final String? message,
  final PregoPopupAlertsNotificationsAction? primaryAction,
  final PregoPopupAlertsNotificationsAction? secondaryAction,
});

/// A floating alert matching Figma's `pregoPopupAlertsNotifications`.
class const PregoPopupAlertsNotifications({
  super.key,
  required final String title,
  final String? message,
  final VoidCallback? onClose,
  final PregoPopupAlertsNotificationsAction? primaryAction,
  final PregoPopupAlertsNotificationsAction? secondaryAction,
  final PregoPopupAlertsNotificationsVariant variant = PregoPopupAlertsNotificationsVariant.info,
}) extends StatelessWidget {
  static const Color _surfaceColor = Color(0xFF333333);
  static const double _iconSize = 22;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(extensions: [...theme.extensions.values, PregoDesignSystem.dark]),
      child: Builder(builder: _buildCard),
    );
  }

  Widget _buildCard(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;

    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(PregoRadius.x2l),
          border: Border.all(color: colors.borderPrimary),
          boxShadow: const [
            BoxShadow(color: Color(0x1A000000), blurRadius: 2),
            BoxShadow(color: Color(0x59000000), spreadRadius: 1),
            BoxShadow(color: Color(0x1A000000), offset: Offset(0, 2), blurRadius: 4),
            BoxShadow(color: Color(0x17000000), offset: Offset(0, 8), blurRadius: 8),
            BoxShadow(color: Color(0x0D000000), offset: Offset(0, 13), blurRadius: 10),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(PregoRadius.x2l),
          child: Stack(
            children: [
              Positioned.fill(child: IgnorePointer(child: _buildAccent(colors))),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  PregoSpacing.xl,
                  PregoSpacing.xl,
                  PregoSpacing.x4l,
                  PregoSpacing.xl,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLeading(colors),
                    const SizedBox(width: PregoSpacing.lg),
                    Expanded(child: _buildContent(prego)),
                  ],
                ),
              ),
              if (onClose case final onClose?)
                PositionedDirectional(
                  top: PregoSpacing.md,
                  end: 7,
                  child: _CloseButton(onPressed: onClose),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(PregoDesignSystem prego) {
    final message = this.message;
    final hasActions = primaryAction != null || secondaryAction != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textPrimary),
        ),
        if (message != null) ...[
          const SizedBox(height: PregoSpacing.lg),
          Text(
            message,
            style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textSecondary),
          ),
        ],
        if (hasActions) ...[
          const SizedBox(height: PregoSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.max,
            children: [
              if (secondaryAction case final action?)
                PregoButtonsSolid(
                  label: action.label,
                  hierarchy: PregoButtonsSolidHierarchy.tertiary,
                  size: PregoButtonsSolidSize.sm,
                  onPressed: action.onPressed,
                ),
              if (primaryAction case final action?) ...[
                const SizedBox(width: PregoSpacing.lg),
                PregoButtonsSolid(
                  label: action.label,
                  hierarchy: _primaryButtonHierarchy,
                  size: PregoButtonsSolidSize.sm,
                  type: _primaryButtonType,
                  onPressed: action.onPressed,
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildLeading(PregoColors colors) {
    if (variant == PregoPopupAlertsNotificationsVariant.loading) {
      return Icon(TablerRegular.sparkles, size: _iconSize, color: colors.textPrimary);
    }
    return Icon(_icon, size: _iconSize, color: _iconColor(colors));
  }

  Widget _buildAccent(PregoColors colors) {
    final accent = switch (variant) {
      PregoPopupAlertsNotificationsVariant.success => colors.fgSuccessSecondary,
      PregoPopupAlertsNotificationsVariant.warning => colors.fgWarningPrimary,
      PregoPopupAlertsNotificationsVariant.error => colors.fgErrorPrimary,
      PregoPopupAlertsNotificationsVariant.info || PregoPopupAlertsNotificationsVariant.loading => null,
    };
    if (accent == null) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.885),
          radius: 0.94,
          transform: const _WideEllipseGradientTransform(6.7),
          colors: [const Color(0x08FFFFFF), accent.withValues(alpha: 0.30)],
        ),
      ),
    );
  }

  IconData get _icon => switch (variant) {
    PregoPopupAlertsNotificationsVariant.info => TablerRegular.info_circle,
    PregoPopupAlertsNotificationsVariant.success => TablerRegular.circle_check,
    PregoPopupAlertsNotificationsVariant.warning => TablerRegular.alert_triangle,
    PregoPopupAlertsNotificationsVariant.error => TablerRegular.alert_circle,
    PregoPopupAlertsNotificationsVariant.loading => TablerRegular.sparkles,
  };

  Color _iconColor(PregoColors colors) => switch (variant) {
    PregoPopupAlertsNotificationsVariant.info || PregoPopupAlertsNotificationsVariant.loading => colors.textPrimary,
    PregoPopupAlertsNotificationsVariant.success => colors.fgSuccessSecondary,
    PregoPopupAlertsNotificationsVariant.warning => colors.fgWarningSecondary,
    PregoPopupAlertsNotificationsVariant.error => colors.fgErrorPrimary,
  };

  PregoButtonsSolidHierarchy get _primaryButtonHierarchy => switch (variant) {
    PregoPopupAlertsNotificationsVariant.loading => PregoButtonsSolidHierarchy.primaryAlt,
    PregoPopupAlertsNotificationsVariant.info ||
    PregoPopupAlertsNotificationsVariant.success ||
    PregoPopupAlertsNotificationsVariant.warning ||
    PregoPopupAlertsNotificationsVariant.error => PregoButtonsSolidHierarchy.primary,
  };

  PregoButtonsSolidType get _primaryButtonType => switch (variant) {
    PregoPopupAlertsNotificationsVariant.success => PregoButtonsSolidType.success,
    PregoPopupAlertsNotificationsVariant.warning => PregoButtonsSolidType.warning,
    PregoPopupAlertsNotificationsVariant.error => PregoButtonsSolidType.destructive,
    PregoPopupAlertsNotificationsVariant.info ||
    PregoPopupAlertsNotificationsVariant.loading => PregoButtonsSolidType.regular,
  };
}

/// Stretches the accent radial into Figma's broad, shallow lower-edge glow.
class const _WideEllipseGradientTransform(final double scaleX) extends GradientTransform {
  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final centerX = bounds.center.dx;
    return Matrix4(
      scaleX,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      centerX * (1 - scaleX),
      0,
      0,
      1,
    );
  }
}

/// A stable presentation target that can be captured before asynchronous work.
final class PregoPopupAlertPresenter._({
  required final OverlayState _overlay,
  required final double _topInset,
}) {
  static final Expando<_PregoPopupAlertPresentation> _presentations = Expando<_PregoPopupAlertPresentation>();

  /// Captures the nearest overlay so an alert can still be shown after the
  /// source widget is removed or a modal route is dismissed.
  static PregoPopupAlertPresenter of(BuildContext context) {
    final overlay = Overlay.of(context);
    return PregoPopupAlertPresenter._(
      overlay: overlay,
      topInset: pregoTopBarInsetOf(
        context: context,
        fallbackTopPadding: MediaQuery.paddingOf(overlay.context).top,
      ),
    );
  }

  /// Shows an alert above the current route and replaces any alert already
  /// visible on the same overlay.
  void show({
    required String title,
    PregoPopupAlertsNotificationsVariant variant = PregoPopupAlertsNotificationsVariant.info,
    PregoPopupAlertContent content = const PregoPopupAlertContent(),
    Duration? duration = const Duration(seconds: 3),
    bool showCloseButton = true,
  }) {
    if (!_overlay.mounted) return;

    _presentations[_overlay]?.dismiss(immediately: true);
    late final _PregoPopupAlertPresentation presentation;
    final entry = OverlayEntry(
      builder: (context) => _PregoPopupAlertOverlay(
        title: title,
        message: content.message,
        variant: variant,
        primaryAction: content.primaryAction,
        secondaryAction: content.secondaryAction,
        duration: duration,
        showCloseButton: showCloseButton,
        onDismissed: () {
          if (_presentations[_overlay] == presentation) {
            _presentations[_overlay] = null;
          }
          presentation.remove();
        },
        presentation: presentation,
        topInset: _topInset,
      ),
    );
    presentation = _PregoPopupAlertPresentation(entry: entry);
    _presentations[_overlay] = presentation;
    _overlay.insert(entry);
  }

  void dismiss() {
    _presentations[_overlay]?.dismiss(immediately: false);
  }
}

final class _PregoPopupAlertPresentation({required final OverlayEntry entry}) {
  VoidCallback? dismissAnimated;
  bool _removed = false;

  void dismiss({required bool immediately}) {
    if (_removed) return;
    final dismiss = dismissAnimated;
    if (!immediately && dismiss != null) {
      dismiss();
      return;
    }
    remove();
  }

  void remove() {
    if (_removed) return;
    _removed = true;
    entry.remove();
    entry.dispose();
  }
}

class const _PregoPopupAlertOverlay({
  required final String title,
  required final String? message,
  required final PregoPopupAlertsNotificationsVariant variant,
  required final PregoPopupAlertsNotificationsAction? primaryAction,
  required final PregoPopupAlertsNotificationsAction? secondaryAction,
  required final Duration? duration,
  required final bool showCloseButton,
  required final VoidCallback onDismissed,
  required final _PregoPopupAlertPresentation presentation,
  required final double topInset,
}) extends StatefulWidget {
  @override
  State<_PregoPopupAlertOverlay> createState() => _PregoPopupAlertOverlayState();
}

class _PregoPopupAlertOverlayState() extends State<_PregoPopupAlertOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 160),
    )..forward();
    widget.presentation.dismissAnimated = _dismiss;
    if (widget.duration case final duration?) {
      _timer = Timer(duration, _dismiss);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.presentation.dismissAnimated = null;
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    _timer?.cancel();
    try {
      await _controller.reverse().orCancel;
    } on TickerCanceled {
      return;
    }
    if (mounted) widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      top: widget.topInset + PregoSpacing.xl,
      start: PregoSpacing.xl,
      end: PregoSpacing.xl,
      child: SafeArea(
          top: false,
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 343),
              child: FadeTransition(
                opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.12),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic)),
                  child: PregoPopupAlertsNotifications(
                    title: widget.title,
                    message: widget.message,
                    variant: widget.variant,
                    primaryAction: widget.primaryAction,
                    secondaryAction: widget.secondaryAction,
                    onClose: widget.showCloseButton ? _dismiss : null,
                  ),
                ),
              ),
            ),
          ),
        ),
    );
  }
}

class const _CloseButton({required final VoidCallback onPressed}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: "Close notification",
      child: PregoTappable(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(PregoRadius.full),
        containerBuilder: (child) => Padding(
          padding: const EdgeInsetsDirectional.all(PregoSpacing.md),
          child: child,
        ),
        child: Icon(
          TablerRegular.x,
          size: 20,
          color: context.prego.colors.textSecondary,
        ),
      ),
    );
  }
}
