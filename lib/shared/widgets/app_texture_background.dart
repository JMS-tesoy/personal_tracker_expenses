import 'package:flutter/material.dart';

class AppTextureBackground extends StatelessWidget {
  const AppTextureBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF343A41),
                  Color(0xFF2D333A),
                  Color(0xFF23282F),
                ],
              ),
            ),
            child: const CustomPaint(painter: _GraphiteTexturePainter()),
          ),
        ),
        child,
      ],
    );
  }
}

class _GraphiteTexturePainter extends CustomPainter {
  const _GraphiteTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final topGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFE8EAED).withValues(alpha: 0.12),
              const Color(0xFFE8EAED).withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.5, -20),
              radius: size.width * 0.8,
            ),
          );
    final lowerShadow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              Colors.black.withValues(alpha: 0.24),
              Colors.black.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.5, size.height + 80),
              radius: size.width,
            ),
          );
    final linePaint = Paint()
      ..color = const Color(0xFF151A20).withValues(alpha: 0.28)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final highlightPaint = Paint()
      ..color = const Color(0xFFE8EAED).withValues(alpha: 0.045)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawRect(Offset.zero & size, topGlow);
    canvas.drawRect(Offset.zero & size, lowerShadow);

    for (double y = 110; y < size.height + 120; y += 155) {
      final path = Path()
        ..moveTo(-40, y)
        ..cubicTo(
          size.width * 0.22,
          y - 34,
          size.width * 0.58,
          y + 34,
          size.width + 40,
          y - 8,
        );
      canvas.drawPath(path, linePaint);
    }

    for (double y = 72; y < size.height; y += 92) {
      for (double x = 44; x < size.width; x += 128) {
        final path = Path()
          ..moveTo(x, y)
          ..lineTo(x + 16, y + 14)
          ..lineTo(x + 32, y);
        canvas.drawPath(path, highlightPaint);
      }
    }

    final vignettePaint = Paint()
      ..shader =
          RadialGradient(
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.18)],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.5, size.height * 0.45),
              radius: size.height * 0.72,
            ),
          );

    canvas.drawRect(Offset.zero & size, vignettePaint);
  }

  @override
  bool shouldRepaint(covariant _GraphiteTexturePainter oldDelegate) {
    return false;
  }
}
