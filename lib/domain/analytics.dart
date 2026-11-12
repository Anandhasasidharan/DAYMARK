import '../core/clock.dart';
import 'models.dart';

class DayMetrics {
  const DayMetrics(this.day, this.studyMinutes, this.planned, this.completed);
  final String day;
  final int studyMinutes, planned, completed;
  double? get completionRate => planned == 0 ? null : completed / planned;
}

List<DayMetrics> dailyMetrics(
  List<TaskRecord> tasks,
  List<ActivityRecord> activities,
  String endDay,
  int days,
) {
  final end = parseDay(endDay);
  return List.generate(days, (index) {
    final day = dateKey(
      DateTime(end.year, end.month, end.day - days + index + 1),
    );
    final dailyTasks = tasks.where((t) => t.day == day).toList();
    final minutes = activities
        .where((a) => a.category == Category.learning && a.day == day)
        .fold<int>(0, (sum, a) => sum + a.minutes);
    return DayMetrics(
      day,
      minutes,
      dailyTasks.length,
      dailyTasks.where((t) => t.done).length,
    );
  });
}
