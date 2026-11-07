import 'dart:math' as math;

import 'challenge.dart';
import 'challenge_task.dart';
import 'challenge_task_log.dart';
import 'challenge_task_progress.dart';
import 'challenge_unit.dart';

enum DayTaskState { done, inProgress, todo, missed }

enum DayState { done, partial, nothing, missed }

class DayTaskStatus {
  const DayTaskStatus({
    required this.task,
    required this.dailyQuota,
    required this.loggedAmount,
    required this.state,
    required this.objectiveReached,
    this.isEstimated = false,
  });
  final ChallengeTask task;
  final double dailyQuota;
  final double loggedAmount;
  final DayTaskState state;
  final bool objectiveReached;
  final bool isEstimated;

  double remainingToCheck(double totalProgress) {
    final dailyRemaining = dailyQuota - loggedAmount;
    final totalRemaining = task.targetValue - totalProgress;
    return math.max(0.0, math.min(dailyRemaining, totalRemaining));
  }
}

class DayPlan {
  const DayPlan({
    required this.dayNumber,
    required this.date,
    required this.tasks,
    required this.isToday,
    required this.isFuture,
    required this.state,
  });
  final int dayNumber;
  final DateTime date;
  final List<DayTaskStatus> tasks;
  final bool isToday;
  final bool isFuture;
  final DayState state;
}

List<DayPlan> buildDayPlans(
  Challenge challenge,
  List<ChallengeTaskProgress> progress,
  List<ChallengeTaskLog> logs,
  DateTime now,
) {
  final today = DateTime.utc(now.year, now.month, now.day);
  final start = DateTime.utc(
    challenge.startDate.year,
    challenge.startDate.month,
    challenge.startDate.day,
  );
  final totals = {for (final p in progress) p.taskId: p};
  final byDay = <String, ChallengeTaskLog>{
    for (final log in logs)
      '${log.taskId}/${ChallengeTaskLog.dateKey(log.logDate)}': log,
  };
  final completionDays = <int, DateTime>{};
  for (final task in challenge.tasks) {
    if (totals[task.id]?.completed != true || task.id == null) continue;
    final taskLogs = logs.where((log) => log.taskId == task.id).toList()
      ..sort((a, b) => a.logDate.compareTo(b.logDate));
    var total = 0.0;
    for (final log in taskLogs) {
      total += log.amount;
      if (total >= task.targetValue - task.targetValue.abs() * 1e-12) {
        completionDays[task.id!] = DateTime.utc(
          log.logDate.year,
          log.logDate.month,
          log.logDate.day,
        );
        break;
      }
    }
  }
  final count = challenge.totalDays;
  return List.generate(count, (index) {
    final date = start.add(Duration(days: index));
    final dayTasks = <DayTaskStatus>[];
    for (final task in challenge.tasks) {
      if (!task.isScheduledOn(date)) continue;
      final dates = task.scheduledDates.map(ChallengeTaskLog.dateKey).toList()
        ..sort();
      final taskCount = dates.isEmpty ? count : dates.length;
      final taskIndex = dates.isEmpty
          ? index
          : dates.indexOf(ChallengeTaskLog.dateKey(date));
      final unit = task.unit == ChallengeUnit.km ? 0.1 : 1.0;
      final initial = task.unit == ChallengeUnit.km
          ? (task.targetValue / taskCount * 10).round() / 10
          : (task.targetValue / taskCount).ceilToDouble();
      final perDay = initial == 0 ? unit : initial;
      final before = math.min(task.targetValue, perDay * taskIndex);
      final quota = math.max(
        0.0,
        taskIndex == taskCount - 1
            ? task.targetValue - before
            : math.min(perDay, task.targetValue - before),
      );
      final log = byDay['${task.id}/${ChallengeTaskLog.dateKey(date)}'];
      final amount = log?.amount ?? 0;
      final completionDay = completionDays[task.id];
      final doneEarlier = completionDay != null && date.isAfter(completionDay);
      final doneOnDay = completionDay != null && date == completionDay;
      final state =
          quota <= 0 ||
              doneEarlier ||
              doneOnDay ||
              amount >= quota - task.targetValue.abs() * 1e-12
          ? DayTaskState.done
          : date.isBefore(today)
          ? DayTaskState.missed
          : amount > 0
          ? DayTaskState.inProgress
          : DayTaskState.todo;
      dayTasks.add(
        DayTaskStatus(
          task: task,
          dailyQuota: quota,
          loggedAmount: amount,
          state: state,
          objectiveReached: doneEarlier,
          isEstimated: log?.isEstimated ?? false,
        ),
      );
    }
    final done =
        dayTasks.isNotEmpty &&
        dayTasks.every((task) => task.state == DayTaskState.done);
    final missed = dayTasks.any((task) => task.state == DayTaskState.missed);
    final partial = dayTasks.any(
      (task) => task.loggedAmount > 0 || task.state == DayTaskState.done,
    );
    return DayPlan(
      dayNumber: index + 1,
      date: date,
      tasks: dayTasks,
      isToday: date == today,
      isFuture: date.isAfter(today),
      state: done
          ? DayState.done
          : missed
          ? DayState.missed
          : partial
          ? DayState.partial
          : DayState.nothing,
    );
  });
}
