import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Loader MyGym : un arc dégradé qui tourne.
class AppLoader extends StatefulWidget {
  final double size;
  final Color color;

  const AppLoader({
    super.key,
    this.size = 44,
    this.color = const Color(0xFFD43DA7),
  });

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _ArcPainter(widget.color),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final Color color;
  _ArcPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.11;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    const sweep = math.pi * 1.5;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: sweep,
        colors: [color.withValues(alpha: 0), color],
      ).createShader(rect);

    canvas.drawArc(rect, 0, sweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) => old.color != color;
}