import "package:cupertino_ui/cupertino_ui.dart"
    show CupertinoDatePicker, CupertinoDatePickerMode, CupertinoTextThemeData, CupertinoTheme, CupertinoThemeData;
import "package:material_ui/material_ui.dart";

import "../../module_prego.dart";

/// What a [PregoDateTimeField] picks.
enum PregoDateTimeFieldMode() {
  /// A time of day; the date part of the value is ignored.
  time,
  dateAndTime,
}

/// The wheel's height, as iOS sizes its own date pickers.
const double _pickerHeight = 216;

/// A grouped row naming [label] and showing [valueLabel]. A tap opens a wheel
/// picker over the page in [showPregoModal]'s frame: a sheet on touch, a
/// dialog under a pointer. Every turn of the wheel reports through
/// [onChanged], so the row behind follows it.
///
/// Place it in [PregoGroupedRows] like any [PregoGroupedRow].
class const PregoDateTimeField({
  super.key,
  required final IconData? icon,
  required final String label,

  /// [value] as the caller words it, such as "9:00 AM" or "Tue, 17 Nov, 9:00 AM".
  required final String valueLabel,

  /// A wall-clock time, never a UTC one, as are [minimum] and what
  /// [onChanged] reports.
  required final DateTime value,
  required final PregoDateTimeFieldMode mode,

  /// The earliest moment the wheel offers, such as now for a one-off time;
  /// null for no limit. A [value] already before it opens on it.
  required final DateTime? minimum,
  required final ValueChanged<DateTime> onChanged,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => PregoGroupedRow(
    icon: icon,
    title: Text(label),
    trailing: Text(
      valueLabel,
      style: context.prego.textTheme.textMd.medium.copyWith(color: context.prego.colors.textPrimary),
    ),
    onTap: () => _open(context: context),
  );

  Future<void> _open({required BuildContext context}) async {
    final minimum = switch (this.minimum) {
      final minimum? => _nextWholeMinute(minimum),
      null => null,
    };
    var initial = _toMinute(value);
    if (minimum != null && initial.isBefore(minimum)) {
      initial = minimum;
      onChanged(minimum);
    }
    await showPregoModal<void>(
      context: context,
      title: label,
      builder: (modalContext) => Padding(
        padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
        child: SizedBox(
          height: _pickerHeight,
          child: CupertinoTheme(
            data: CupertinoThemeData(
              brightness: Theme.of(modalContext).brightness,
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: modalContext.prego.textTheme.textXl.regular.copyWith(
                  color: modalContext.prego.colors.textPrimary,
                ),
              ),
            ),
            child: CupertinoDatePicker(
              mode: switch (mode) {
                PregoDateTimeFieldMode.time => CupertinoDatePickerMode.time,
                PregoDateTimeFieldMode.dateAndTime => CupertinoDatePickerMode.dateAndTime,
              },
              initialDateTime: initial,
              minimumDate: minimum,
              use24hFormat: MediaQuery.alwaysUse24HourFormatOf(modalContext),
              onDateTimeChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }

  /// [moment] without seconds, which the wheel cannot show.
  static DateTime _toMinute(DateTime moment) =>
      DateTime(moment.year, moment.month, moment.day, moment.hour, moment.minute);

  /// The first whole minute at or after [moment], so the earliest choice is
  /// never already behind it.
  static DateTime _nextWholeMinute(DateTime moment) {
    final minute = _toMinute(moment);
    return minute == moment ? minute : minute.add(const Duration(minutes: 1));
  }
}
