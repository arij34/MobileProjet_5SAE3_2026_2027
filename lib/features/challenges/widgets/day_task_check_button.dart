import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/day_plan.dart';

class DayTaskCheckButton extends StatelessWidget {
  const DayTaskCheckButton({
    super.key,
    required this.state,
    required this.onPressed,
  });

  final DayTaskState state;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: state == DayTaskState.done
          ? 'Tâche terminée'
          : 'Marquer la tâche du jour comme terminée',
      onPressed: onPressed,
      icon: Icon(switch (state) {
        DayTaskState.done => Icons.check_circle,
        DayTaskState.inProgress => Icons.timelapse,
        DayTaskState.todo || DayTaskState.missed => Icons.circle_outlined,
      }),
      color: state == DayTaskState.done ? AppTheme.success : AppTheme.primary,
      disabledColor: state == DayTaskState.done
          ? AppTheme.success
          : AppTheme.textSecondary,
    );
  }
}
