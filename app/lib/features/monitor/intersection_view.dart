import 'package:flutter/material.dart';

import '../../data/models.dart';

/// Top-down drawing of the intersection: roads, junction box, signal dots
/// and the queued vehicles in each lane.
class IntersectionView extends StatelessWidget {
  const IntersectionView({super.key, required this.frame});

  final LiveFrame frame;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.2,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: _IntersectionPainter(frame),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _IntersectionPainter extends CustomPainter {
  _IntersectionPainter(this.frame);

  final LiveFrame frame;

  static const _carLength = 14.0;
  static const _carWidth = 8.0;
  static const _gap = 4.0;

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

    final roadWidth = w * 0.30;
    final roadHeight = h * 0.34;
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

    _dot(canvas, box.topLeft + const Offset(-9, -9), 'north');
    _dot(canvas, box.topRight + const Offset(9, -9), 'east');
    _dot(canvas, box.bottomRight + const Offset(9, 9), 'south');
    _dot(canvas, box.bottomLeft + const Offset(-9, 9), 'west');

    final laneOffsetX = roadWidth * 0.22;
    final laneOffsetY = roadHeight * 0.22;
    const step = _carLength + _gap;

    // North: queue above the box, heading south, on the left side.
    _queue(
      canvas,
      lane: 'north',
      fit: ((box.top - 12) / step).floor(),
      center: (i) => Offset(cx - laneOffsetX, box.top - 12 - _carLength / 2 - i * step),
      vertical: true,
    );
    // South: queue below the box, heading north, on the right side.
    _queue(
      canvas,
      lane: 'south',
      fit: ((h - box.bottom - 12) / step).floor(),
      center: (i) => Offset(cx + laneOffsetX, box.bottom + 12 + _carLength / 2 + i * step),
      vertical: true,
    );
    // East: queue right of the box, heading west, on the upper side.
    _queue(
      canvas,
      lane: 'east',
      fit: ((w - box.right - 12) / step).floor(),
      center: (i) => Offset(box.right + 12 + _carLength / 2 + i * step, cy - laneOffsetY),
      vertical: false,
    );
    // West: queue left of the box, heading east, on the lower side.
    _queue(
      canvas,
      lane: 'west',
      fit: ((box.left - 12) / step).floor(),
      center: (i) => Offset(box.left - 12 - _carLength / 2 - i * step, cy + laneOffsetY),
      vertical: false,
    );
  }

  void _dot(Canvas canvas, Offset at, String lane) {
    final signal = frame.lane(lane)?.signal ?? 'stop';
    final color = switch (signal) {
      'go' => const Color(0xFF22C55E),
      'yellow' => const Color(0xFFF5A623),
      'flashYellow' => const Color(0xFFFFC400),
      _ => const Color(0xFFEF4444),
    };
    canvas.drawCircle(at, 4.5, Paint()..color = color);
  }

  void _queue(
    Canvas canvas, {
    required String lane,
    required int fit,
    required Offset Function(int) center,
    required bool vertical,
  }) {
    final info = frame.lane(lane);
    if (info == null || info.vehicleCount <= 0) return;

    final shown = info.vehicleCount < fit ? info.vehicleCount : (fit < 0 ? 0 : fit);
    final hasEmergency = frame.emergencyLane == lane;

    for (var i = 0; i < shown; i++) {
      final isEmergency = hasEmergency && i == 0;
      final rect = Rect.fromCenter(
        center: center(i),
        width: vertical ? _carWidth : _carLength,
        height: vertical ? _carLength : _carWidth,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2.5));
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = isEmergency
              ? const Color(0xFFEF4444)
              : const Color(0xFF1F9D55),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = isEmergency
              ? Colors.white
              : const Color(0xFF34D399)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    final extra = info.vehicleCount - shown;
    if (extra > 0) {
      final painter = TextPainter(
        text: TextSpan(
          text: '+$extra',
          style: const TextStyle(
            color: Color(0xFF9A9AA0),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final last = center(shown > 0 ? shown - 1 : 0);
      final offset = vertical
          ? Offset(
              last.dx - painter.width / 2,
              lane == 'north'
                  ? last.dy - _carLength / 2 - painter.height - 1
                  : last.dy + _carLength / 2 + 1,
            )
          : Offset(
              lane == 'east'
                  ? last.dx + _carLength / 2 + 3
                  : last.dx - _carLength / 2 - painter.width - 3,
              last.dy - painter.height / 2,
            );
      painter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant _IntersectionPainter oldDelegate) =>
      oldDelegate.frame != frame;
}
