import 'package:flutter/material.dart';

import '../../design/themes/extensions/night_theme.dart';
import '../../design/tokens/spacing.dart';
import '../../design/tokens/typography.dart';

class XiguangInput extends StatelessWidget {
  const XiguangInput({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.maxLines = 1,
    this.onChanged,
    this.autofocus = false,
    this.textInputAction,
    this.obscureText = false,
    this.onSubmitted,
    this.maxLength,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!,
              style: AppText.caption.copyWith(color: theme.foregroundMuted)),
          const SizedBox(height: AppSpacing.s6),
        ],
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          autofocus: autofocus,
          textInputAction: textInputAction,
          obscureText: obscureText,
          onSubmitted: onSubmitted,
          maxLength: maxLength,
          style: AppText.body.copyWith(color: theme.foreground),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
