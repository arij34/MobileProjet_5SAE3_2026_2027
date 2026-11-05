import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'nutrition_ui.dart';

/// Anneau de progression (calories restantes au centre) dessiné en CustomPaint.
class CaloriesRing extends StatelessWidget {
  final double consumed;
  final double goal;
  final double size;
  const CaloriesRing({
    super.key,
    required this.consumed,
    required this.goal,
    this.size = 170,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = goal <= 0 ? 0.0 : (consumed / goal).clamp(0.0, 1.0);
    final remaining = (goal - consumed);
    final over = remaining < 0;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          ratio: ratio,
          color: over ? NColors.danger : NColors.primary,
          track: NColors.lavender,
          stroke: 14,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                over
                    ? '+${(-remaining).round()}'
                    : '${remaining.round()}',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: over ? NColors.danger : NColors.textDark,
                ),
              ),
              Text(
                over ? 'kcal dépassées' : 'kcal restantes',
                style: const TextStyle(
                    color: NColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text('${consumed.round()} / ${goal.round()}',
                  style: const TextStyle(
                      color: NColors.textSecondary, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double ratio;
  final Color color;
  final Color track;
  final double stroke;
  _RingPainter({
    required this.ratio,
    required this.color,
    required this.track,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * ratio, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.ratio != ratio || old.color != color;
}

/// Barre de progression d'un macronutriment (consommé / objectif).
class MacroBar extends StatelessWidget {
  final String label;
  final double consumed;
  final double goal;
  final String unit;
  final Color color;
  const MacroBar({
    super.key,
    required this.label,
    required this.consumed,
    required this.goal,
    required this.color,
    this.unit = 'g',
  });

  @override
  Widget build(BuildContext context) {
    final ratio = goal <= 0 ? 0.0 : (consumed / goal).clamp(0.0, 1.0);
    final over = goal > 0 && consumed > goal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: NColors.textDark, fontWeight: FontWeight.w600)),
            Text(
              '${consumed.round()} / ${goal.round()} $unit',
              style: TextStyle(
                  color: over ? NColors.danger : NColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 9,
            backgroundColor: NColors.lavender,
            valueColor:
                AlwaysStoppedAnimation(over ? NColors.danger : color),
          ),
        ),
      ],
    );
  }
}
