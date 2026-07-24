import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/composites/xiguang_page.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../reminder/application/reminder_providers.dart';
import '../../../reminder/application/reminder_controller.dart';
import '../../../reminder/domain/reminder_settings.dart';

class ReminderSettingsPage extends ConsumerWidget {
  const ReminderSettingsPage({super.key});

  Future<void> _update(
    BuildContext context,
    WidgetRef ref,
    ReminderSettings current,
    ReminderSettings next,
  ) async {
    final enabling = (!current.captureReminder && next.captureReminder) ||
        (!current.oldLightReminder && next.oldLightReminder) ||
        (!current.islandQuietReminder && next.islandQuietReminder);
    if (enabling) {
      final allowed =
          await ref.read(reminderControllerProvider).requestPermission();
      if (!allowed && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('系统没有授予通知权限，可以稍后在系统设置中开启。'),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
    }
    final privacyMode = ref.read(authSessionProvider)?.privacyMode ?? 'private';
    await ref.read(reminderControllerProvider).saveAndSchedule(
          next,
          showPreview: privacyMode == 'balanced',
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = NightTheme.of(context);
    final state = ref.watch(reminderSettingsProvider);
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
          Text('GENTLE SIGNAL',
              style: AppText.eyebrow.copyWith(color: theme.accent)),
          const SizedBox(height: AppSpacing.sm),
          Text('柔光提醒', style: AppText.hero.copyWith(color: theme.foreground)),
          const SizedBox(height: AppSpacing.s12),
          Text('提醒默认全部关闭。开启后由系统在合适的时间轻轻敲一下，不做连续打卡。',
              style: AppText.body.copyWith(color: theme.foregroundMuted)),
          const SizedBox(height: AppSpacing.lg),
          state.when(
            loading: () =>
                Center(child: CircularProgressIndicator(color: theme.accent)),
            error: (_, __) => const Text('暂时无法读取提醒设置。'),
            data: (settings) => Column(
              children: [
                _ReminderSwitch(
                  title: '很久没有捕光',
                  subtitle: '距离最近一束光 7 天后提醒一次',
                  value: settings.captureReminder,
                  onChanged: (value) => _update(
                    context,
                    ref,
                    settings,
                    settings.copyWith(captureReminder: value),
                  ),
                ),
                _ReminderSwitch(
                  title: '旧光回访',
                  subtitle: '存在 30 天前的光片时，3 天后安排一次回访',
                  value: settings.oldLightReminder,
                  onChanged: (value) => _update(
                    context,
                    ref,
                    settings,
                    settings.copyWith(oldLightReminder: value),
                  ),
                ),
                _ReminderSwitch(
                  title: '小岛静默',
                  subtitle: '距离最近一束光 30 天后提醒看看小岛',
                  value: settings.islandQuietReminder,
                  onChanged: (value) => _update(
                    context,
                    ref,
                    settings,
                    settings.copyWith(islandQuietReminder: value),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderSwitch extends StatelessWidget {
  const _ReminderSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Text(title,
          style: AppText.bodyStrong.copyWith(color: theme.foreground)),
      subtitle: Text(subtitle,
          style: AppText.caption.copyWith(color: theme.foregroundMuted)),
    );
  }
}
