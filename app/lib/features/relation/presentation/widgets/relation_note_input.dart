import 'package:flutter/material.dart';

import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/typography.dart';

class RelationNoteInput extends StatelessWidget {
  const RelationNoteInput({
    super.key,
    required this.controller,
    this.maxLength = 60,
  });

  final TextEditingController controller;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 3,
      maxLines: 4,
      maxLength: maxLength,
      style: AppText.body,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.white.withValues(alpha: .72),
        hintText: '它们都像是被一句话轻轻击中的时刻。',
        hintStyle: AppText.placeholder,
        counterStyle: AppText.caption,
        contentPadding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: .76)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.teaGreen, width: 1.2),
        ),
      ),
    );
  }
}
