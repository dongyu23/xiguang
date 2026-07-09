import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../ui/composites/xiguang_bottom_sheet.dart';
import '../../../../ui/composites/xiguang_card.dart';

/// 平台感知的图片选择器。
///
/// - 移动端（iOS/Android）：弹出底部面板，提供「拍照」和「从相册选择」两个入口。
/// - 桌面端（Windows/macOS/Linux）：直接打开系统文件选择器，不做额外底部面板。
Future<List<XFile>> pickImageAttachments({
  required BuildContext context,
  required ImagePicker picker,
  int limit = 6,
}) async {
  if (_isDesktop) {
    return _pickFromDesktop(limit);
  }
  return _pickFromMobile(context, picker, limit);
}

final bool _isDesktop =
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

// ── 桌面：直接用 file_picker 选图 ──

Future<List<XFile>> _pickFromDesktop(int limit) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: true,
  );
  if (result == null || result.files.isEmpty) return const [];
  return result.files
      .take(limit)
      .where((f) => f.path != null)
      .map((f) => XFile(f.path!))
      .toList();
}

// ── 移动端：底部面板 → camera / gallery ──

Future<List<XFile>> _pickFromMobile(
  BuildContext context,
  ImagePicker picker,
  int limit,
) async {
  final source = await showModalBottomSheet<_ImageSource>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => XiguangBottomSheet(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _SourceTile(
          icon: Icons.photo_camera_outlined,
          title: '拍照',
          subtitle: '使用相机拍一张新照片',
          onTap: () => Navigator.of(context).pop(_ImageSource.camera),
        ),
        const SizedBox(height: AppSpacing.s10),
        _SourceTile(
          icon: Icons.photo_library_outlined,
          title: '从相册选择',
          subtitle: '从相册或图片文件中选择照片',
          onTap: () => Navigator.of(context).pop(_ImageSource.gallery),
        ),
      ]),
    ),
  );
  if (source == null) return const [];

  switch (source) {
    case _ImageSource.camera:
      try {
        final image = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 960,
          maxHeight: 960,
          imageQuality: 76,
        );
        return image == null ? const [] : [image];
      } catch (_) {
        return const [];
      }
    case _ImageSource.gallery:
      try {
        return await picker.pickMultiImage(
          limit: limit,
          maxWidth: 960,
          maxHeight: 960,
          imageQuality: 76,
        );
      } catch (_) {
        return const [];
      }
  }
}

enum _ImageSource { camera, gallery }

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return XiguangCard(
      variant: XiguangCardVariant.outlined,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s14,
        vertical: AppSpacing.s13,
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.accent.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, color: theme.accent, size: 22),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppText.titleSmall.copyWith(color: theme.foreground)),
              const SizedBox(height: AppSpacing.s3),
              Text(subtitle,
                  style:
                      AppText.caption.copyWith(color: theme.foregroundMuted)),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: theme.foregroundMuted),
      ]),
    );
  }
}
