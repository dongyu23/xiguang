import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/composites/xiguang_page.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class PrivacySettingsPage extends ConsumerWidget {
  const PrivacySettingsPage({super.key});

  Future<void> _setPreview(WidgetRef ref, bool enabled) async {
    final session = ref.read(authSessionProvider);
    if (session == null) return;
    await ref.read(authActionsControllerProvider.notifier).updateProfile(
          nickname: session.nickname,
          avatarKey: session.avatarKey,
          aiEnabled: session.aiEnabled,
          privacyMode: enabled ? 'balanced' : 'private',
        );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final password = TextEditingController();
    final phrase = TextEditingController();
    var busy = false;
    String? error;
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('删除账号'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('账号删除后将立即退出，所有设备的登录状态都会失效。这个操作不能在 App 内撤销。'),
              const SizedBox(height: AppSpacing.s14),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: '当前密码'),
              ),
              const SizedBox(height: AppSpacing.s12),
              TextField(
                controller: phrase,
                decoration: const InputDecoration(labelText: '输入“删除”以确认'),
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.s10),
                Text(error!,
                    style: TextStyle(color: NightTheme.of(context).danger)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed:
                  busy ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.sunsetCoral,
                foregroundColor: AppColors.white,
              ),
              onPressed: busy
                  ? null
                  : () async {
                      if (password.text.isEmpty || phrase.text.trim() != '删除') {
                        setState(() => error = '请填写当前密码，并输入“删除”。');
                        return;
                      }
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await ref
                            .read(authActionsControllerProvider.notifier)
                            .deleteAccount(password: password.text);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } catch (_) {
                        setState(() {
                          busy = false;
                          error = '删除失败，请确认密码或稍后重试。';
                        });
                      }
                    },
              child: Text(busy ? '删除中…' : '删除账号'),
            ),
          ],
        ),
      ),
    );
    password.dispose();
    phrase.dispose();
    if (deleted == true && context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = NightTheme.of(context);
    final session = ref.watch(authSessionProvider);
    final previewEnabled = session?.privacyMode == 'balanced';
    return XiguangPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            tooltip: '返回',
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_rounded, color: theme.foreground),
          ),
          const SizedBox(height: AppSpacing.s6),
          Text('BOUNDARY',
              style: AppText.eyebrow.copyWith(color: theme.accent)),
          const SizedBox(height: AppSpacing.sm),
          Text('隐私设置', style: AppText.hero.copyWith(color: theme.foreground)),
          const SizedBox(height: AppSpacing.s12),
          Text('决定哪些内容可以出现在系统界面，以及账号和数据如何退出。',
              style: AppText.body.copyWith(color: theme.foregroundMuted)),
          const SizedBox(height: AppSpacing.xl),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: previewEnabled,
            onChanged: (value) => _setPreview(ref, value),
            title: Text('通知中显示光片预览',
                style: AppText.bodyStrong.copyWith(color: theme.foreground)),
            subtitle: Text(
              previewEnabled ? '提醒可以显示一小段文字' : '提醒只显示“有一束旧光想见你”',
              style: AppText.caption.copyWith(color: theme.foregroundMuted),
            ),
          ),
          const SizedBox(height: AppSpacing.s18),
          Text('数据说明',
              style: AppText.titleMedium.copyWith(color: theme.foreground)),
          const SizedBox(height: AppSpacing.s9),
          Text(
            '隙光不提供公开主页。AI 只在主动触发时读取你选中的内容；密码、登录令牌和后端地址不会进入数据归档。',
            style: AppText.body.copyWith(color: theme.foregroundMuted),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Divider(color: theme.border),
          const SizedBox(height: AppSpacing.s18),
          Text('危险操作',
              style: AppText.titleMedium.copyWith(color: theme.danger)),
          const SizedBox(height: AppSpacing.s9),
          Text(
            '建议先在“数据归档”导出完整归档。删除账号后，当前设备和其他设备都会退出。',
            style: AppText.body.copyWith(color: theme.foregroundMuted),
          ),
          const SizedBox(height: AppSpacing.s14),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.danger,
              side: BorderSide(color: theme.danger.withValues(alpha: .55)),
            ),
            onPressed: () => _deleteAccount(context, ref),
            child: const Text('删除账号…'),
          ),
        ],
      ),
    );
  }
}
