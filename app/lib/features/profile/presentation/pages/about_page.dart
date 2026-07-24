import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/composites/xiguang_page.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

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
          Text('ABOUT XIGUANG',
              style: AppText.eyebrow.copyWith(color: theme.accent)),
          const SizedBox(height: AppSpacing.sm),
          Text('关于隙光', style: AppText.hero.copyWith(color: theme.foreground)),
          const SizedBox(height: AppSpacing.s12),
          Text(
            '我可以在这里，不用解释自己。',
            style: AppText.titleMedium.copyWith(color: theme.foreground),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '隙光是一处私人多媒体记录空间。文字、图片和声音先成为光片，沿时间成线，在线间相遇，最后慢慢长成属于你的岛。',
            style: AppText.body.copyWith(color: theme.foregroundMuted),
          ),
          const SizedBox(height: AppSpacing.s18),
          Text(
            'AI 只在你主动触发时提供候选建议，不在后台解释你，也不替你做决定。',
            style: AppText.body.copyWith(color: theme.foregroundMuted),
          ),
          const SizedBox(height: AppSpacing.xl),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              final version = info == null
                  ? '读取中…'
                  : '${info.version} (${info.buildNumber})';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoLine(label: '版本', value: version),
                  const SizedBox(height: AppSpacing.s10),
                  const _InfoLine(label: '数据边界', value: '默认私密，不提供公开主页与社交功能'),
                  const SizedBox(height: AppSpacing.s10),
                  const _InfoLine(
                      label: '核心路径', value: '隙中捕光 · 光入成线 · 线间可织 · 织久成屿'),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('隐私说明',
              style: AppText.titleMedium.copyWith(color: theme.foreground)),
          const SizedBox(height: AppSpacing.s9),
          Text(
            '账号凭据不会写入数据归档；归档 ZIP 为明文文件，需要由你妥善保存。图片和声音只用于你主动发起的记录、同步或恢复操作。删除账号入口位于“隐私设置”的最下方，并需要密码确认。',
            style: AppText.body.copyWith(color: theme.foregroundMuted),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(label,
              style: AppText.caption.copyWith(color: theme.foregroundMuted)),
        ),
        Expanded(
          child: Text(value,
              style: AppText.body.copyWith(color: theme.foreground)),
        ),
      ],
    );
  }
}
