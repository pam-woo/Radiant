import 'package:flutter/material.dart';

import '../theme.dart';

class RadiantLogo extends StatelessWidget {
  const RadiantLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _Dot(RadiantColors.red),
        SizedBox(width: 4),
        _Dot(RadiantColors.yellow),
        SizedBox(width: 4),
        _Dot(RadiantColors.green),
        SizedBox(width: 12),
        Text(
          'RADIANT',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
