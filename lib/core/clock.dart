import 'package:timezone/timezone.dart' as tz;

String dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

DateTime parseDay(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null || dateKey(parsed) != value) {
    throw const FormatException('Use a valid date in YYYY-MM-DD format.');
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}

class AppClock {
  AppClock(this.zone, {DateTime Function()? now}) : _now = now ?? DateTime.now;
  final String zone;
  final DateTime Function() _now;
  DateTime get now => tz.TZDateTime.from(_now(), tz.getLocation(zone));
  String get today => dateKey(now);
  String localStamp(String utc) {
    final local = tz.TZDateTime.from(DateTime.parse(utc), tz.getLocation(zone));
    return '${dateKey(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} $zone';
  }
}
