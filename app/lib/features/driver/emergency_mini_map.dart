import 'package:flutter/material.dart';

/// Small top-down map showing which side the emergency vehicle comes from.
class EmergencyMiniMap extends StatelessWidget {
  const EmergencyMiniMap({
    super.key,
    required this.lane,
    required this.vehicleLabel,
    this.visible = true,
  });

  /// "north", "south", "east" or "west".
  final String lane;
  final String vehicleLabel;

  /// False once the vehicle has passed, so only the roads are drawn.
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.7,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: _MiniMapPainter(lane, vehicleLabel.toUpperCase(), visible),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter(this.lane, this.label, this.visible);

  final String lane;
  final String label;
  final bool visible;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF111113),
    );

    final roadWidth = w * 0.18;
    final roadHeight = h * 0.30;
    final road = Paint()..color = const Color(0xFF2A2A2E);
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy), width: w, height: roadHeight),
      road,
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy), width: roadWidth, height: h),
      road,
    );

    final box = Rect.fromCenter(
      center: Offset(cx, cy),
      width: roadWidth,
      height: roadHeight,
    );
    final yellow = Paint()
      ..color = const Color(0xFFFFC400)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(box, yellow);
    canvas.drawLine(box.topLeft, box.bottomRight, yellow);
    canvas.drawLine(box.topRight, box.bottomLeft, yellow);

    _text(canvas, 'NORTH', Offset(cx, 8), const Color(0xFF9A9AA0));
    _text(canvas, 'SOUTH', Offset(cx, h - 8), const Color(0xFF9A9AA0));
    _text(canvas, 'WEST', Offset(22, cy - 16), const Color(0xFF9A9AA0));
    _text(canvas, 'EAST', Offset(w - 22, cy - 16), const Color(0xFF9A9AA0));

    if (!visible) return;

    // Vehicle on its approach lane, driving on the right-hand side.
    const long = 22.0;
    const short = 10.0;
    final offX = roadWidth * 0.22;
    final offY = roadHeight * 0.22;
    late final Offset center;
    late final bool vertical;
    switch (lane) {
      case 'north':
        center = Offset(cx - offX, box.top - 26);
        vertical = true;
      case 'south':
        center = Offset(cx + offX, box.bottom + 26);
        vertical = true;
      case 'east':
        center = Offset(box.right + 34, cy - offY);
        vertical = false;
      default:
        center = Offset(box.left - 34, cy + offY);
        vertical = false;
    }

    final rect = Rect.fromCenter(
      center: center,
      width: vertical ? short : long,
      height: vertical ? long : short,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFFEF4444));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    _text(
      canvas,
      label,
      Offset(center.dx, center.dy + (vertical ? long / 2 + 8 : 14)),
      const Color(0xFFEF4444),
    );
  }

  void _text(Canvas canvas, String text, Offset center, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) =>
      oldDelegate.lane != lane ||
      oldDelegate.label != label ||
      oldDelegate.visible != visible;
}
