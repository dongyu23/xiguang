import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/typography.dart';

Future<List<XFile>> pickImageAttachments({
  required BuildContext context,
  required ImagePicker picker,
  int limit = 6,
}) async {
  final source = await showModalBottomSheet<_ImageAttachmentSource>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _ImageSourceTile(
            icon: Icons.photo_camera_outlined,
            title: '拍照',
            subtitle: '使用相机拍一张新照片',
            onTap: () =>
                Navigator.of(context).pop(_ImageAttachmentSource.camera),
          ),
          const SizedBox(height: 10),
          _ImageSourceTile(
            icon: Icons.photo_library_outlined,
            title: '从相册选择',
            subtitle: '从相册或图片文件中选择照片',
            onTap: () =>
                Navigator.of(context).pop(_ImageAttachmentSource.gallery),
          ),
        ]),
      ),
    ),
  );
  if (source == null) return const [];
  switch (source) {
    case _ImageAttachmentSource.camera:
      final image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 960,
        maxHeight: 960,
        imageQuality: 76,
      );
      return image == null ? const [] : [image];
    case _ImageAttachmentSource.gallery:
      return picker.pickMultiImage(
        limit: limit,
        maxWidth: 960,
        maxHeight: 960,
        imageQuality: 76,
      );
  }
}

enum _ImageAttachmentSource { camera, gallery }

class _ImageSourceTile extends StatelessWidget {
  const _ImageSourceTile({
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
    return Material(
      color: AppColors.paper.withValues(alpha: .62),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.teaGreen.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.teaGreen, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.titleSmall),
                  const SizedBox(height: 3),
                  Text(subtitle, style: AppText.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
          ]),
        ),
      ),
    );
  }
}
