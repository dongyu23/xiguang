import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/spaces/space_canvas.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientProvider);
    final session = ref.watch(authSessionProvider);
    final nightMode = ref.watch(nightModeProvider);
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: AtmosphereBackground()),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      tooltip: '返回',
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: nightMode ? AppText.nightInkMuted : AppColors.ink,
                    ),
                    Text('SETTINGS',
                        style: AppText.onNight(AppText.eyebrow, nightMode)),
                    const SizedBox(height: 8),
                    Text('设置', style: AppText.onNight(AppText.hero, nightMode)),
                    const SizedBox(height: 18),
                    _Panel(children: [
                      Text('账号', style: AppText.titleMedium),
                      const SizedBox(height: 10),
                      _Row(label: '用户名', value: session?.username ?? '-'),
                      _Row(label: '昵称', value: session?.nickname ?? '-'),
                      _Row(
                        label: '状态',
                        value: session == null ? '未登录' : '后端同步',
                      ),
                    ]),
                    const SizedBox(height: 14),
                    _Panel(children: [
                      Text('后端连接', style: AppText.titleMedium),
                      const SizedBox(height: 10),
                      _Row(label: 'API', value: api.baseUrl),
                      _Row(
                        label: 'Token',
                        value: api.hasToken ? '已保存访问令牌' : '未登录',
                      ),
                    ]),
                    const SizedBox(height: 14),
                    _Panel(children: [
                      Text('产品边界', style: AppText.titleMedium),
                      const SizedBox(height: 10),
                      Text('AI 只作为星图管理员预留，不后台分析，不替你解释。', style: AppText.body),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: softDecoration(AppColors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 64, child: Text(label, style: AppText.caption)),
        Expanded(child: Text(value, style: AppText.body)),
      ]),
    );
  }
}
