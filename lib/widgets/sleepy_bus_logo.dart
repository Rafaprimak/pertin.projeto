import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:pertin/theme/app_colors.dart';

class SleepyBusLogo extends StatelessWidget {
  final double size;
  final bool animated;

  const SleepyBusLogo({
    super.key,
    this.size = 150,
    this.animated = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: animated
          ? _AnimatedBusLogo(size: size)
          : _StaticBusLogo(size: size),
    );
  }
}

class _AnimatedBusLogo extends StatefulWidget {
  final double size;

  const _AnimatedBusLogo({required this.size});

  @override
  State<_AnimatedBusLogo> createState() => _AnimatedBusLogoState();
}

class _AnimatedBusLogoState extends State<_AnimatedBusLogo>
    with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _zzController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _zzController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _floatAnimation = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    _zzController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_floatAnimation, _zzController]),
      builder: (context, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Transform.translate(
              offset: Offset(0, _floatAnimation.value),
              child: _StaticBusLogo(size: widget.size),
            ),
            // ZZZ animation
            Positioned(
              right: -10,
              top: 0,
              child: _buildZzz(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildZzz() {
    final opacity = (math.sin(_zzController.value * math.pi * 2) + 1) / 2;
    return Opacity(
      opacity: opacity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'z',
            style: TextStyle(
              color: AppColors.starYellow,
              fontSize: widget.size * 0.12,
              fontWeight: FontWeight.bold,
            ),
          ),
          Transform.translate(
            offset: const Offset(8, -5),
            child: Text(
              'Z',
              style: TextStyle(
                color: AppColors.starYellow.withOpacity(0.8),
                fontSize: widget.size * 0.15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(18, -10),
            child: Text(
              'Z',
              style: TextStyle(
                color: AppColors.starYellow.withOpacity(0.6),
                fontSize: widget.size * 0.18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaticBusLogo extends StatelessWidget {
  final double size;

  const _StaticBusLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _BusPainter(),
    );
  }
}

class _BusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;

    // Sombra do ônibus
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(s * 0.12, s * 0.18, s * 0.76, s * 0.62),
        topLeft: const Radius.circular(25),
        topRight: const Radius.circular(25),
        bottomLeft: const Radius.circular(8),
        bottomRight: const Radius.circular(8),
      ),
      shadowPaint,
    );

    // Corpo principal do ônibus (visto de frente)
    final bodyPaint = Paint()
      ..color = AppColors.babyBlue
      ..style = PaintingStyle.fill;

    final bodyRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(s * 0.1, s * 0.15, s * 0.8, s * 0.6),
      topLeft: const Radius.circular(25),
      topRight: const Radius.circular(25),
      bottomLeft: const Radius.circular(8),
      bottomRight: const Radius.circular(8),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // Teto / Destino do ônibus
    final roofPaint = Paint()
      ..color = AppColors.lightBlue
      ..style = PaintingStyle.fill;

    final roofRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(s * 0.15, s * 0.12, s * 0.7, s * 0.1),
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
    );
    canvas.drawRRect(roofRect, roofPaint);

    // Letreiro de destino
    final destinationPaint = Paint()
      ..color = AppColors.midnightBlue
      ..style = PaintingStyle.fill;

    final destinationRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.2, s * 0.14, s * 0.6, s * 0.06),
      const Radius.circular(4),
    );
    canvas.drawRRect(destinationRect, destinationPaint);

    // Grande para-brisa frontal
    final windshieldPaint = Paint()
      ..color = AppColors.midnightBlue
      ..style = PaintingStyle.fill;

    final windshieldRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.15, s * 0.24, s * 0.7, s * 0.28),
      const Radius.circular(12),
    );
    canvas.drawRRect(windshieldRect, windshieldPaint);

    // Reflexo no para-brisa
    final reflectionPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final reflectionPath = Path()
      ..moveTo(s * 0.18, s * 0.26)
      ..lineTo(s * 0.35, s * 0.26)
      ..lineTo(s * 0.25, s * 0.45)
      ..lineTo(s * 0.18, s * 0.45)
      ..close();
    canvas.drawPath(reflectionPath, reflectionPaint);

    // Olhos fechados (dormindo) - no para-brisa
    final eyePaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Olho esquerdo fechado (linha curvada para baixo = dormindo)
    final leftEyePath = Path()
      ..moveTo(s * 0.28, s * 0.36)
      ..quadraticBezierTo(s * 0.35, s * 0.42, s * 0.42, s * 0.36);
    canvas.drawPath(leftEyePath, eyePaint);

    // Olho direito fechado
    final rightEyePath = Path()
      ..moveTo(s * 0.58, s * 0.36)
      ..quadraticBezierTo(s * 0.65, s * 0.42, s * 0.72, s * 0.36);
    canvas.drawPath(rightEyePath, eyePaint);

    // Bochechas rosadas
    final blushPaint = Paint()
      ..color = Colors.pinkAccent.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(s * 0.25, s * 0.44), width: s * 0.1, height: s * 0.05),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(s * 0.75, s * 0.44), width: s * 0.1, height: s * 0.05),
      blushPaint,
    );

    // Boquinha dormindo (sorriso suave)
    final mouthPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path()
      ..moveTo(s * 0.42, s * 0.46)
      ..quadraticBezierTo(s * 0.5, s * 0.50, s * 0.58, s * 0.46);
    canvas.drawPath(mouthPath, mouthPaint);

    // Grade frontal (sorriso do ônibus)
    final grillPaint = Paint()
      ..color = AppColors.navyBlue
      ..style = PaintingStyle.fill;

    final grillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.25, s * 0.55, s * 0.5, s * 0.08),
      const Radius.circular(6),
    );
    canvas.drawRRect(grillRect, grillPaint);

    // Linhas da grade
    final grillLinePaint = Paint()
      ..color = AppColors.deepBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (int i = 1; i < 5; i++) {
      canvas.drawLine(
        Offset(s * (0.25 + i * 0.1), s * 0.56),
        Offset(s * (0.25 + i * 0.1), s * 0.62),
        grillLinePaint,
      );
    }

    // Faróis grandes (olhos do ônibus quando acordado, agora só decorativos)
    final headlightOuterPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.fill;

    final headlightInnerPaint = Paint()
      ..color = AppColors.starYellow
      ..style = PaintingStyle.fill;

    // Farol esquerdo
    canvas.drawCircle(Offset(s * 0.2, s * 0.58), s * 0.06, headlightOuterPaint);
    canvas.drawCircle(Offset(s * 0.2, s * 0.58), s * 0.04, headlightInnerPaint);

    // Farol direito
    canvas.drawCircle(Offset(s * 0.8, s * 0.58), s * 0.06, headlightOuterPaint);
    canvas.drawCircle(Offset(s * 0.8, s * 0.58), s * 0.04, headlightInnerPaint);

    // Brilho dos faróis
    final headlightGlowPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(s * 0.18, s * 0.56), s * 0.015, headlightGlowPaint);
    canvas.drawCircle(Offset(s * 0.78, s * 0.56), s * 0.015, headlightGlowPaint);

    // Para-choque
    final bumperPaint = Paint()
      ..color = AppColors.deepBlue
      ..style = PaintingStyle.fill;

    final bumperRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.12, s * 0.68, s * 0.76, s * 0.06),
      const Radius.circular(4),
    );
    canvas.drawRRect(bumperRect, bumperPaint);

    // Rodas (vistas de frente - aparecem nas laterais)
    final wheelPaint = Paint()
      ..color = AppColors.deepBlue
      ..style = PaintingStyle.fill;

    // Roda esquerda
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.05, s * 0.72, s * 0.1, s * 0.12),
        const Radius.circular(4),
      ),
      wheelPaint,
    );

    // Roda direita
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.85, s * 0.72, s * 0.1, s * 0.12),
        const Radius.circular(4),
      ),
      wheelPaint,
    );

    // Calota das rodas
    final hubPaint = Paint()
      ..color = AppColors.navyBlue
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(s * 0.1, s * 0.78), s * 0.03, hubPaint);
    canvas.drawCircle(Offset(s * 0.9, s * 0.78), s * 0.03, hubPaint);

    // Retrovisores
    final mirrorPaint = Paint()
      ..color = AppColors.navyBlue
      ..style = PaintingStyle.fill;

    // Retrovisor esquerdo
    final leftMirrorPath = Path()
      ..moveTo(s * 0.08, s * 0.3)
      ..lineTo(s * 0.02, s * 0.28)
      ..lineTo(s * 0.02, s * 0.36)
      ..lineTo(s * 0.08, s * 0.34)
      ..close();
    canvas.drawPath(leftMirrorPath, mirrorPaint);

    // Retrovisor direito
    final rightMirrorPath = Path()
      ..moveTo(s * 0.92, s * 0.3)
      ..lineTo(s * 0.98, s * 0.28)
      ..lineTo(s * 0.98, s * 0.36)
      ..lineTo(s * 0.92, s * 0.34)
      ..close();
    canvas.drawPath(rightMirrorPath, mirrorPaint);

    // Bordas decorativas laterais
    final sidePaint = Paint()
      ..color = AppColors.lightBlue
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(s * 0.1, s * 0.52, s * 0.05, s * 0.16), sidePaint);
    canvas.drawRect(Rect.fromLTWH(s * 0.85, s * 0.52, s * 0.05, s * 0.16), sidePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
