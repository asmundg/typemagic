import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiParticle {
  double x, y;
  double vx, vy;
  double rotation;
  double rotationSpeed;
  Color color;
  double width, height;
  double opacity;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.width,
    required this.height,
    this.opacity = 1.0,
  });
}

class ConfettiOverlay extends StatefulWidget {
  final Duration duration;
  final VoidCallback? onComplete;

  const ConfettiOverlay({
    super.key,
    this.duration = const Duration(milliseconds: 2500),
    this.onComplete,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<ConfettiParticle> _particles;
  final _random = Random();

  static const _gravity = 600.0; // px/s²
  static const _particleCount = 80;

  static const _colors = [
    Color(0xFFe2b714), // gold
    Color(0xFF4ec9b0), // teal
    Color(0xFFca4754), // red
    Color(0xFF7c3aed), // purple
    Color(0xFF4a9eff), // blue
    Color(0xFFffd700), // bright gold
    Color(0xFFff6b6b), // coral
    Color(0xFF48dbfb), // sky
  ];

  @override
  void initState() {
    super.initState();
    _particles = _generateParticles();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onComplete?.call();
        }
      })
      ..forward();
  }

  List<ConfettiParticle> _generateParticles() {
    return List.generate(_particleCount, (_) {
      final angle = _random.nextDouble() * pi - pi / 2; // -90° to +90°
      final speed = 300.0 + _random.nextDouble() * 500.0;
      return ConfettiParticle(
        x: 0,
        y: 0,
        vx: cos(angle) * speed * (0.5 + _random.nextDouble()),
        vy: -speed * (0.6 + _random.nextDouble() * 0.4),
        rotation: _random.nextDouble() * 2 * pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 12,
        color: _colors[_random.nextInt(_colors.length)],
        width: 4 + _random.nextDouble() * 6,
        height: 6 + _random.nextDouble() * 10,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ConfettiPainter(
          particles: _particles,
          progress: _controller.value,
          totalSeconds: widget.duration.inMilliseconds / 1000.0,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  final double progress;
  final double totalSeconds;

  _ConfettiPainter({
    required this.particles,
    required this.progress,
    required this.totalSeconds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * totalSeconds;
    final centerX = size.width / 2;
    final centerY = size.height * 0.4;

    for (final p in particles) {
      final x = centerX + p.x + p.vx * t;
      final y = centerY + p.y + p.vy * t + 0.5 * _ConfettiOverlayState._gravity * t * t;
      final rotation = p.rotation + p.rotationSpeed * t;

      // Fade out in the last 40%
      final opacity = progress > 0.6
          ? (1.0 - (progress - 0.6) / 0.4).clamp(0.0, 1.0)
          : 1.0;

      if (opacity <= 0 || y > size.height + 50) continue;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity * 0.9);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.width, height: p.height),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
