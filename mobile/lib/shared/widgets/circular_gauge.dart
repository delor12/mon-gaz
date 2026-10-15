import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class CircularGauge extends StatelessWidget {
  final double percent;
  final double weightKg;
  final double size;

  const CircularGauge({
    Key? key,
    required this.percent,
    required this.weightKg,
    this.size = 230,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final clampedPct = percent.clamp(0.0, 100.0);

    Color gaugeColor = AppColors.gold;
    if (clampedPct <= 5.0) {
      gaugeColor = AppColors.alertRed;
    } else if (clampedPct <= 15.0) {
      gaugeColor = AppColors.yellow;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _GaugePainter(
              percent: clampedPct,
              activeColor: gaugeColor,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${clampedPct.toStringAsFixed(1)} %',
                style: TextStyle(
                  fontSize: size * 0.16,
                  fontWeight: FontWeight.w800,
                  color: gaugeColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${weightKg.toStringAsFixed(2)} kg',
                style: TextStyle(
                  fontSize: size * 0.09,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Gaz restant',
                style: TextStyle(
                  fontSize: size * 0.055,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percent;
  final Color activeColor;

  _GaugePainter({required this.percent, required this.activeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;
    const strokeWidth = 14.0;

    // Piste de fond
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    // Arc de jauge doré/coloré
    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -pi / 2;
    final sweepAngle = 2 * pi * (percent / 100.0);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.percent != percent || oldDelegate.activeColor != activeColor;
  }
}
