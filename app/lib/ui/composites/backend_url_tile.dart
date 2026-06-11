import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../design/tokens/colors.dart';
import '../../design/tokens/typography.dart';

/// 登录/注册页面的后端地址切换按钮
class BackendUrlTile extends ConsumerWidget {
  const BackendUrlTile({super.key, this.loading = false});
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseUrl = ref.watch(apiBaseUrlProvider).valueOrNull ?? '';
    final host = Uri.tryParse(baseUrl)?.host ?? baseUrl;
    return Center(
      child: TextButton.icon(
        onPressed: loading ? null : () => _showUrlSheet(context, ref),
        icon: const Icon(Icons.dns_outlined, size: 15, color: AppColors.inkMuted),
        label: Text(host.isNotEmpty ? host : '后端地址',
            style: AppText.caption.copyWith(color: AppColors.inkMuted)),
      ),
    );
  }

  void _showUrlSheet(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(
        text: ref.read(apiBaseUrlProvider).valueOrNull ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(999)),
                ),
                const SizedBox(height: 16),
                Text('后端地址', style: AppText.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'http://192.168.1.2:8088/api/v1',
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await ref.read(apiBaseUrlProvider.notifier).reset();
                        Navigator.of(context).pop();
                      },
                      child: const Text('恢复默认'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final value = controller.text.trim();
                        try {
                          await ref.read(apiBaseUrlProvider.notifier).save(value);
                          Navigator.of(context).pop();
                        } on ArgumentError catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(e.message.toString()),
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      },
                      child: const Text('保存'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
