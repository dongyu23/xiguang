import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../design/tokens/colors.dart';
import '../../design/tokens/spacing.dart';
import '../../design/tokens/typography.dart';

/// 全局错误边界 — 捕获 Flutter 渲染错误并上报 Sentry
class SentryErrorBoundary extends StatefulWidget {
  const SentryErrorBoundary({super.key, required this.child});

  final Widget child;

  @override
  State<SentryErrorBoundary> createState() => _SentryErrorBoundaryState();
}

class _SentryErrorBoundaryState extends State<SentryErrorBoundary> {
  FlutterErrorDetails? _errorDetails;

  @override
  void initState() {
    super.initState();
    final originalHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      originalHandler?.call(details);
      _reportError(details);
      if (mounted) {
        setState(() => _errorDetails = details);
      }
    };
  }

  void _reportError(FlutterErrorDetails details) {
    try {
      Sentry.captureException(
        details.exception,
        stackTrace: details.stack,
      );
    } catch (_) {
      // Sentry 本身不应导致崩溃
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorDetails != null) {
      return Material(
        child: Container(
          color: AppColors.paper,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wb_twilight, size: 48, color: AppColors.teaGreen),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '一道微光闪烁了一下。',
                  style: AppText.body.copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${_errorDetails!.exception}',
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(color: AppColors.inkSubtle),
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: () => setState(() => _errorDetails = null),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return widget.child;
  }
}
