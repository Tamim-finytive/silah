import 'package:intl/intl.dart';

/// Backend prayer times are stored as 24-hour values; show users 12-hour time.
String formatPrayerTime(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty || raw == '--') return raw.isEmpty ? '--' : raw;

  final withMeridiem = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*([AaPp][Mm])$')
      .firstMatch(raw);
  if (withMeridiem != null) {
    final hour = int.tryParse(withMeridiem.group(1)!);
    final minute = int.tryParse(withMeridiem.group(2)!);
    if (hour != null && minute != null && hour >= 1 && hour <= 12 && minute < 60) {
      final isPm = withMeridiem.group(3)!.toUpperCase() == 'PM';
      final date = DateTime(2000, 1, 1, (hour % 12) + (isPm ? 12 : 0), minute);
      return DateFormat('h:mm a').format(date);
    }
  }

  final match = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(raw);
  if (match == null) return raw;
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null || hour > 23 || minute > 59) return raw;
  return DateFormat('h:mm a').format(DateTime(2000, 1, 1, hour, minute));
}
