import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:pertin/theme/app_colors.dart';

class StarrySkyBackground extends StatefulWidget {
  final Widget child;
  final bool animated;

  const StarrySkyBackground({
    super.key,
    required this.child,
    this.animated = true,
  });

  @override
  State<StarrySkyBackground> createState() => _StarrySkyBackgroundState();
}

class _StarrySkyBackgroundState extends State<StarrySkyBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Star> _stars = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    if (widget.animated) {
      _controller.repeat();
    }

    // Gera estrelas
    for (int i = 0; i < 80; i++) {
      _stars.add(Star(
        x: _random.nextDouble(),
        y: _random.nextDouble() * 0.6, // Apenas na parte superior
        size: _random.nextDouble() * 2 + 1,
        twinkleSpeed: _random.nextDouble() * 2 + 1,
        twinkleOffset: _random.nextDouble() * math.pi * 2,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.nightSkyGradient,
      ),
      child: Stack(
        children: [
          // Estrelas
          if (widget.animated)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _StarsPainter(
                    stars: _stars,
                    animationValue: _controller.value,
                  ),
                );
              },
            )
          else
            CustomPaint(
              size: Size.infinite,
              painter: _StarsPainter(
                stars: _stars,
                animationValue: 0,
              ),
            ),

          // Estrada
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(MediaQuery.of(context).size.width, 150),
              painter: _RoadPainter(),
            ),
          ),

          // Conteúdo
          widget.child,
        ],
      ),
    );
  }
}

class Star {
  final double x;
  final double y;
  final double size;
  final double twinkleSpeed;
  final double twinkleOffset;

  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.twinkleSpeed,
    required this.twinkleOffset,
  });
}

class _StarsPainter extends CustomPainter {
  final List<Star> stars;
  final double animationValue;

  _StarsPainter({required this.stars, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    for (var star in stars) {
      final opacity = (math.sin(
                  animationValue * math.pi * 2 * star.twinkleSpeed +
                      star.twinkleOffset) +
              1) /
          2 *
          0.5 +
          0.5;

      final paint = Paint()
        ..color = AppColors.starYellow.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.size,
        paint,
      );

      // Brilho extra para algumas estrelas
      if (star.size > 2) {
        final glowPaint = Paint()
          ..color = AppColors.starYellow.withOpacity(opacity * 0.3)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

        canvas.drawCircle(
          Offset(star.x * size.width, star.y * size.height),
          star.size * 2,
          glowPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class _RoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Asfalto
    final asphaltPaint = Paint()
      ..color = const Color(0xFF1A1A2E)
      ..style = PaintingStyle.fill;

    final roadPath = Path()
      ..moveTo(0, size.height * 0.3)
      ..lineTo(size.width, size.height * 0.3)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(roadPath, asphaltPaint);

    // Linha do horizonte (grama/terra)
    final horizonPaint = Paint()
      ..color = const Color(0xFF2D3436)
      ..style = PaintingStyle.fill;

    final horizonPath = Path()
      ..moveTo(0, size.height * 0.1)
      ..quadraticBezierTo(
          size.width * 0.5, size.height * 0.2, size.width, size.height * 0.1)
      ..lineTo(size.width, size.height * 0.3)
      ..lineTo(0, size.height * 0.3)
      ..close();

    canvas.drawPath(horizonPath, horizonPaint);

    // Faixas da estrada
    final linePaint = Paint()
      ..color = AppColors.starYellow.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final stripeWidth = size.width * 0.08;
    final stripeHeight = size.height * 0.03;
    final gapWidth = stripeWidth * 1.5;
    final startY = size.height * 0.6;

    for (double x = 0; x < size.width; x += stripeWidth + gapWidth) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, startY, stripeWidth, stripeHeight),
          const Radius.circular(2),
        ),
        linePaint,
      );
    }

    // Linha lateral esquerda (apenas no canto)
    final sideLine = Paint()
      ..color = AppColors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(0, size.height * 0.35),
      Offset(0, size.height),
      sideLine,
    );

    // Linha lateral direita (apenas no canto)
    canvas.drawLine(
      Offset(size.width, size.height * 0.35),
      Offset(size.width, size.height),
      sideLine,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
