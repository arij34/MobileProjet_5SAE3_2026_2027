import 'package:flutter/material.dart';

import '../models/weight_entry.dart';
import 'nutrition_ui.dart';

/// Courbe d'évolution du poids (CustomPaint, sans dépendance externe).
class WeightChart extends StatelessWidget {
  final List<WeightEntry> entries;
  final double height;
  const WeightChart({super.key, required this.entries, this.height = 140});

  @override
  Widget build(BuildContext context) {
    if (entries.length < 2) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('Enregistrez au moins 2 poids pour voir la courbe.',
              style: TextStyle(color: NColors.textSecondary, fontSize: 12)),
        ),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _WeightPainter(entries)),
    );
  }
}

class _WeightPainter extends CustomPainter {
  final List<WeightEntry> entries;
  _WeightPainter(this.entries);

  @override
  void paint(Canvas canvas, Size size) {
    final weights = entries.map((e) => e.weight).toList();
    final minW = weights.reduce((a, b) => a < b ? a : b);
    final maxW = weights.reduce((a, b) => a > b ? a : b);
    final range = (maxW - minW).abs() < 0.5 ? 1.0 : (maxW - minW);

    const padLeft = 8.0, padRight = 8.0, padTop = 16.0, padBottom = 16.0;
    final chartW = size.width - padLeft - padRight;
    final chartH = size.height - padTop - padBottom;

    final points = <Offset>[];
    for (var i = 0; i < entries.length; i++) {
      final x = padLeft + chartW * (i / (entries.length - 1));
      final norm = (entries[i].weight - minW) / range;
      final y = padTop + chartH * (1 - norm);
      points.add(Offset(x, y));
    }

    // Aire sous la courbe (dégradé léger).
    final fill = Path()..moveTo(points.first.dx, size.height - padBottom);
    for (final p in points) {
      fill.lineTo(p.dx, p.dy);
    }
    fill.lineTo(points.last.dx, size.height - padBottom);
    fill.close();
    canvas.drawPath(
      fill,
      Paint()..color = NColors.primary.withValues(alpha: 0.10),
    );

    // Ligne.
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = NColors.primary,
    );

    // Points.
    final dot = Paint()..color = NColors.primary;
    final dotInner = Paint()..color = Colors.white;
    for (final p in points) {
      canvas.drawCircle(p, 4, dot);
      canvas.drawCircle(p, 1.8, dotInner);
    }

    // Min / max en texte.
    _label(canvas, '${maxW.toStringAsFixed(1)} kg', Offset(padLeft, 0));
    _label(canvas, '${minW.toStringAsFixed(1)} kg',
        Offset(padLeft, size.height - padBottom + 2));
  }

  void _label(Canvas canvas, String text, Offset at) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: NColors.textSecondary, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _WeightPainter old) =>
      old.entries.length != entries.length;
}
