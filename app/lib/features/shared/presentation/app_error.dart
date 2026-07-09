import 'package:flutter/material.dart';

import '../../../design/tokens/colors.dart';
import '../../../design/tokens/motion.dart';
import '../../../design/tokens/typography.dart';
import '../domain/app_exception.dart';

/// 统一错误提示。presentation 层 catch AppException 后调此函数，不自造 SnackBar。
void showAppError(BuildContext context, AppException e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        e.message,
        style: AppText.body.copyWith(color: AppColors.white),
      ),
      backgroundColor: AppColors.sunsetCoral,
      duration: AppMotion.snackbar,
    ),
  );
}
