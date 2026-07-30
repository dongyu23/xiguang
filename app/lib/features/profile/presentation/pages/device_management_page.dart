import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/composites/xiguang_page.dart';
import '../../../auth/domain/device_session.dart';
import '../../../auth/application/device_management_controller.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class DeviceManagementPage extends ConsumerStatefulWidget {
  const DeviceManagementPage({super.key});

  @override
  ConsumerState<DeviceManagementPage> createState() =>
      _DeviceManagementPageState();
}

class _DeviceManagementPageState extends ConsumerState<DeviceManagementPage> {
  late Future<(List<DeviceSession>, String)> _devices;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _devices = _load();
  }

  Future<(List<DeviceSession>, String)> _load() async {
    return ref.read(deviceManagementControllerProvider).load();
  }

  Future<void> _revoke(DeviceSession device, bool current) async {
    if (_busy.contains(device.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(current ? '退出当前设备？' : '退出这台设备？'),
        content: Text(
            current ? '当前设备会立即返回登录页。' : '${device.deviceName} 下次访问时需要重新登录。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('退出设备')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy.add(device.id));
    try {
      await ref.read(deviceManagementControllerProvider).revoke(device.id);
      if (current) {
        await ref.read(authActionsControllerProvider.notifier).logout();
        if (mounted) context.go('/login');
        return;
      }
      if (mounted) setState(_reload);
    } finally {
      if (mounted) setState(() => _busy.remove(device.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
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
          Text('SIGNED IN',
              style: AppText.eyebrow.copyWith(color: theme.accent)),
          const SizedBox(height: AppSpacing.sm),
          Text('登录设备', style: AppText.hero.copyWith(color: theme.foreground)),
          const SizedBox(height: AppSpacing.s12),
          Text('查看仍然持有登录会话的设备，也可以让其中一台退出。',
              style: AppText.body.copyWith(color: theme.foregroundMuted)),
          const SizedBox(height: AppSpacing.lg),
          FutureBuilder<(List<DeviceSession>, String)>(
            future: _devices,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Center(
                    child: CircularProgressIndicator(color: theme.accent));
              }
              if (snapshot.hasError) {
                return TextButton.icon(
                  onPressed: () => setState(_reload),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('读取失败，重新尝试'),
                );
              }
              final (items, currentId) = snapshot.data!;
              return Column(
                children: [
                  for (final device in items)
                    _DeviceTile(
                      device: device,
                      current: device.isCurrent || device.deviceId == currentId,
                      busy: _busy.contains(device.id),
                      onRevoke: () => _revoke(
                        device,
                        device.isCurrent || device.deviceId == currentId,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.current,
    required this.busy,
    required this.onRevoke,
  });

  final DeviceSession device;
  final bool current;
  final bool busy;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final date = device.createdAt.toLocal();
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s10),
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: theme.surfaceHigh.withValues(alpha: .68),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Icon(Icons.devices_rounded,
              color: current ? theme.accent : theme.foregroundMuted),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(device.deviceName,
                        style: AppText.bodyStrong
                            .copyWith(color: theme.foreground)),
                  ),
                  if (current) ...[
                    const SizedBox(width: AppSpacing.s6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s6,
                        vertical: AppSpacing.s2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.accent.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text('当前设备',
                          style: AppText.caption.copyWith(color: theme.accent)),
                    ),
                  ],
                ]),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${date.year}年${date.month}月${date.day}日登录',
                  style: AppText.caption.copyWith(color: theme.foregroundMuted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: busy ? null : onRevoke,
            child: Text('退出',
                style: AppText.chip.copyWith(color: AppColors.sunsetCoral)),
          ),
        ],
      ),
    );
  }
}
