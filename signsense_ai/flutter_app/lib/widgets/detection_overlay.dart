import 'package:flutter/material.dart';
import '../models/detection_result.dart';
import '../utils/app_theme.dart';

/// Paints bounding boxes on top of the camera preview
class DetectionOverlay extends StatelessWidget {
  final List<DetectionResult> detections;

  const DetectionOverlay({super.key, required this.detections});

  @override
  Widget build(BuildContext context) {
    if (detections.isEmpty) return const SizedBox.shrink();

    return CustomPaint(
      painter: _BoundingBoxPainter(detections),
      size: Size.infinite,
    );
  }
}

class _BoundingBoxPainter extends CustomPainter {
  final List<DetectionResult> detections;

  _BoundingBoxPainter(this.detections);

  static const Map<String, Color> _categoryColors = {
    'object': AppTheme.ibmBlue,
    'traffic': AppTheme.ibmYellow,
    'vehicle': AppTheme.ibmRed,
    'person': AppTheme.ibmGreen,
    'face': AppTheme.ibmPurple,
  };

  @override
  void paint(Canvas canvas, Size size) {
    for (final detection in detections) {
      if (detection.bbox == null) continue;

      final color = _categoryColors[detection.category] ?? AppTheme.ibmBlue;
      final bbox = detection.bbox!;

      // Scale bbox coordinates to canvas size (bbox is 0.0–1.0 normalized)
      final rect = Rect.fromLTRB(
        bbox.x1 * size.width,
        bbox.y1 * size.height,
        bbox.x2 * size.width,
        bbox.y2 * size.height,
      );

      // Draw bounding box
      final boxPaint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawRect(rect, boxPaint);

      // Draw corner accents
      _drawCorners(canvas, rect, color);

      // Draw label background
      final labelText =
          '${detection.label} ${(detection.confidence * 100).toStringAsFixed(0)}%';
      _drawLabel(canvas, rect, labelText, color);
    }
  }

  void _drawCorners(Canvas canvas, Rect rect, Color color) {
    const cornerLen = 14.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(rect.topLeft, rect.topLeft.translate(cornerLen, 0), paint);
    canvas.drawLine(rect.topLeft, rect.topLeft.translate(0, cornerLen), paint);

    // Top-right
    canvas.drawLine(rect.topRight, rect.topRight.translate(-cornerLen, 0), paint);
    canvas.drawLine(rect.topRight, rect.topRight.translate(0, cornerLen), paint);

    // Bottom-left
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft.translate(cornerLen, 0), paint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft.translate(0, -cornerLen), paint);

    // Bottom-right
    canvas.drawLine(rect.bottomRight, rect.bottomRight.translate(-cornerLen, 0), paint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight.translate(0, -cornerLen), paint);
  }

  void _drawLabel(Canvas canvas, Rect rect, String label, Color color) {
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );

    final textSpan = TextSpan(text: label, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final labelRect = Rect.fromLTWH(
      rect.left,
      rect.top - 22,
      textPainter.width + 10,
      20,
    );

    // Background pill
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(3)),
      Paint()..color = color,
    );

    textPainter.paint(canvas, Offset(rect.left + 5, rect.top - 22));
  }

  @override
  bool shouldRepaint(_BoundingBoxPainter old) {
    return old.detections != detections;
  }
}
