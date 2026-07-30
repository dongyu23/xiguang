import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/composites/xiguang_button.dart';
import '../../../../ui/composites/xiguang_card.dart';
import '../../../../ui/composites/xiguang_empty_state.dart';
import '../../../../ui/composites/xiguang_page.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../../application/stats_providers.dart';

class TideInsightPage extends ConsumerWidget {
  const TideInsightPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insight = ref.watch(tideInsightProvider);
    final theme = NightTheme.of(context);
    return XiguangPage(
      backgroundLayer: const AtmosphereBackground(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(
            tooltip: '返回',
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/mine'),
            icon: Icon(Icons.arrow_back_rounded, color: theme.foreground),
          ),
          const SizedBox(width: AppSpacing.s10),
          Text('潮汐提示',
              style: AppText.titleLarge.copyWith(color: theme.foreground)),
        ]),
        const SizedBox(height: AppSpacing.s18),
        insight.when(
          data: (item) => XiguangCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.waves_rounded, color: theme.accent, size: 28),
              const SizedBox(height: AppSpacing.s14),
              Text(item.title,
                  style: AppText.titleMedium.copyWith(color: theme.foreground)),
              const SizedBox(height: AppSpacing.sm),
              Text(item.message,
                  style: AppText.body.copyWith(color: theme.foregroundMuted)),
              if (item.occurrences > 0) ...[
                const SizedBox(height: AppSpacing.s14),
                Text('近 14 天出现 ${item.occurrences} 次',
                    style:
                        AppText.caption.copyWith(color: theme.foregroundMuted)),
              ],
            ]),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => XiguangEmptyState(
            title: '潮汐提示暂时不可用',
            description: '星光会员可以在这里轻轻回看近期反复出现的感受。',
            icon: Icons.lock_outline_rounded,
            action: XiguangButton(
              label: '查看会员',
              expand: false,
              onPressed: () => context.push('/membership'),
            ),
          ),
        ),
      ]),
    );
  }
}
