import 'package:flutter/material.dart';

import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';

class AuthNotice extends StatelessWidget {
  const AuthNotice({super.key, required this.message, this.nightMode = false});

  final String message;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    final textColor = nightMode ? AppText.nightInk : AppColors.ink;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12, vertical: AppSpacing.s10),
      decoration: BoxDecoration(
        color: AppColors.sunsetCoral.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.sunsetCoral.withValues(alpha: .28)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: AppColors.sunsetCoral.withValues(alpha: .95),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: AppText.caption.copyWith(
              color: textColor,
              height: 1.35,
            ),
          ),
        ),
      ]),
    );
  }
}
