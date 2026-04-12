import 'package:flutter/material.dart';
import '../features/touch_training/touch_exercises.dart';

/// Draws two stylized hands with fingers that light up based on [activeFinger].
class HandGuide extends StatelessWidget {
  final Finger? activeFinger;
  const HandGuide({super.key, this.activeFinger});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Hand(
          isLeft: true,
          activeFinger: activeFinger,
        ),
        const SizedBox(width: 24),
        _Hand(
          isLeft: false,
          activeFinger: activeFinger,
        ),
      ],
    );
  }
}

class _Hand extends StatelessWidget {
  final bool isLeft;
  final Finger? activeFinger;

  const _Hand({required this.isLeft, this.activeFinger});

  static const _fingerWidth = 20.0;
  static const _fingerGap = 6.0;
  static const _fingerRadius = 8.0;

  // Finger heights from pinky to index (left hand order).
  // We'll mirror for right hand.
  static const _fingerHeights = [48.0, 64.0, 72.0, 60.0];

  List<Finger> get _fingers => isLeft
      ? [Finger.leftPinky, Finger.leftRing, Finger.leftMiddle, Finger.leftIndex]
      : [Finger.rightIndex, Finger.rightMiddle, Finger.rightRing, Finger.rightPinky];

  List<double> get _heights => isLeft
      ? _fingerHeights
      : _fingerHeights.reversed.toList();

  @override
  Widget build(BuildContext context) {
    final totalWidth =
        _fingers.length * _fingerWidth + (_fingers.length - 1) * _fingerGap;
    final maxHeight = _heights.reduce((a, b) => a > b ? a : b);
    const palmHeight = 40.0;
    const thumbHeight = 28.0;
    const thumbWidth = 24.0;

    return SizedBox(
      width: totalWidth + 16, // extra for thumb overhang
      height: maxHeight + palmHeight + 8,
      child: CustomPaint(
        painter: _HandPainter(
          fingers: _fingers,
          heights: _heights,
          activeFinger: activeFinger,
          isLeft: isLeft,
          fingerWidth: _fingerWidth,
          fingerGap: _fingerGap,
          fingerRadius: _fingerRadius,
          palmHeight: palmHeight,
          thumbHeight: thumbHeight,
          thumbWidth: thumbWidth,
          maxFingerHeight: maxHeight,
        ),
      ),
    );
  }
}

class _HandPainter extends CustomPainter {
  final List<Finger> fingers;
  final List<double> heights;
  final Finger? activeFinger;
  final bool isLeft;
  final double fingerWidth;
  final double fingerGap;
  final double fingerRadius;
  final double palmHeight;
  final double thumbHeight;
  final double thumbWidth;
  final double maxFingerHeight;

  _HandPainter({
    required this.fingers,
    required this.heights,
    required this.activeFinger,
    required this.isLeft,
    required this.fingerWidth,
    required this.fingerGap,
    required this.fingerRadius,
    required this.palmHeight,
    required this.thumbHeight,
    required this.thumbWidth,
    required this.maxFingerHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Offset to center the fingers (leave room for thumb)
    final xOffset = isLeft ? 0.0 : 16.0;

    // Draw palm
    final palmTop = maxFingerHeight;
    final palmLeft = xOffset;
    final palmRight =
        xOffset + fingers.length * fingerWidth + (fingers.length - 1) * fingerGap;
    final palmRect = RRect.fromLTRBR(
      palmLeft,
      palmTop - 4, // overlap slightly with fingers
      palmRight,
      palmTop + palmHeight,
      const Radius.circular(10),
    );
    canvas.drawRRect(
      palmRect,
      Paint()..color = const Color(0xFF2A2A3A),
    );

    // Draw fingers
    for (var i = 0; i < fingers.length; i++) {
      final isActive = fingers[i] == activeFinger;
      final color = fingerColors[fingers[i]]!;
      final x = xOffset + i * (fingerWidth + fingerGap);
      final h = heights[i];
      final y = maxFingerHeight - h;

      final rect = RRect.fromLTRBR(
        x,
        y,
        x + fingerWidth,
        maxFingerHeight + 4, // overlap into palm
        Radius.circular(fingerRadius),
      );

      // Fill
      canvas.drawRRect(
        rect,
        Paint()
          ..color = isActive
              ? color.withValues(alpha: 0.7)
              : color.withValues(alpha: 0.12),
      );

      // Border
      canvas.drawRRect(
        rect,
        Paint()
          ..color = isActive
              ? color
              : color.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isActive ? 2.5 : 1.0,
      );

      // Glow for active finger
      if (isActive) {
        canvas.drawRRect(
          rect.inflate(3),
          Paint()
            ..color = color.withValues(alpha: 0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }

    // Draw thumb
    final thumbX = isLeft
        ? palmRight - thumbWidth * 0.3
        : xOffset - thumbWidth * 0.7 + 16;
    final thumbY = palmTop + 6;

    // Thumb is angled outward: we rotate a rounded rect
    canvas.save();
    canvas.translate(
      thumbX + thumbWidth / 2,
      thumbY + thumbHeight / 2,
    );
    canvas.rotate(isLeft ? 0.5 : -0.5);
    final thumbRect = RRect.fromLTRBR(
      -thumbWidth / 2,
      -thumbHeight / 2,
      thumbWidth / 2,
      thumbHeight / 2,
      Radius.circular(fingerRadius),
    );
    canvas.drawRRect(
      thumbRect,
      Paint()..color = const Color(0xFF2A2A3A),
    );
    canvas.drawRRect(
      thumbRect,
      Paint()
        ..color = const Color(0xFF4A4A5A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HandPainter old) => old.activeFinger != activeFinger;
}
