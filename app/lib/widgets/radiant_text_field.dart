import 'package:flutter/material.dart';

import '../theme.dart';

enum FieldStatus { neutral, error, valid }

class RadiantTextField extends StatelessWidget {
  const RadiantTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.onChanged,
    this.obscure = false,
    this.status = FieldStatus.neutral,
    this.message,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool obscure;
  final FieldStatus status;
  final String? message;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  Color get _borderColor => switch (status) {
        FieldStatus.error => RadiantColors.red,
        FieldStatus.valid => RadiantColors.green,
        FieldStatus.neutral => RadiantColors.surfaceBorder,
      };

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color, width: 1.5),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            filled: true,
            fillColor: RadiantColors.surface,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            enabledBorder: border(_borderColor),
            focusedBorder: status == FieldStatus.neutral
                ? border(RadiantColors.textMuted)
                : border(_borderColor),
            border: border(_borderColor),
          ),
        ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              message!,
              style: TextStyle(
                fontSize: 11,
                color: status == FieldStatus.valid
                    ? RadiantColors.green
                    : RadiantColors.red,
              ),
            ),
          ),
      ],
    );
  }
}
