// PAGE_SIZE_EXEMPT: 会员状态、方案和渠道需要在同一购买流程中完整呈现。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/composites/xiguang_button.dart';
import '../../../../ui/composites/xiguang_card.dart';
import '../../../../ui/composites/xiguang_empty_state.dart';
import '../../../../ui/composites/xiguang_page.dart';
import '../../../../ui/primitives/overlay_snackbar.dart';
import '../../application/membership_controller.dart';
import '../../domain/membership.dart';

class MembershipPage extends ConsumerStatefulWidget {
  const MembershipPage({super.key});

  @override
  ConsumerState<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends ConsumerState<MembershipPage> {
  String _period = 'year';

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(membershipProvider);
    return XiguangPage(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s18,
        AppSpacing.s10,
        AppSpacing.s18,
        AppSpacing.pageBottomNav + MediaQuery.paddingOf(context).bottom,
      ),
      child: membership.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: XiguangEmptyState(
            title: '暂时读不到会员状态',
            description: '请稍后再试。',
            icon: Icons.cloud_off_outlined,
          ),
        ),
        data: (status) => _MembershipContent(
          status: status,
          period: _period,
          onPeriodChanged: (value) => setState(() => _period = value),
        ),
      ),
    );
  }
}

class _MembershipContent extends ConsumerWidget {
  const _MembershipContent({
    required this.status,
    required this.period,
    required this.onPeriodChanged,
  });

  final MembershipStatus status;
  final String period;
  final ValueChanged<String> onPeriodChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = NightTheme.of(context);
    final hasBillingNotice = status.pendingOrderStatus.isNotEmpty ||
        const {'grace', 'past_due', 'revoked', 'expired'}
            .contains(status.status);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        IconButton(
          tooltip: '返回',
          visualDensity: VisualDensity.compact,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.arrow_back_rounded, color: theme.foreground),
        ),
        const SizedBox(width: AppSpacing.s6),
        Expanded(
          child: Text('隙光会员',
              style: AppText.titleLarge.copyWith(color: theme.foreground)),
        ),
      ]),
      const SizedBox(height: AppSpacing.s14),
      _CurrentMembershipPanel(status: status),
      if (hasBillingNotice) ...[
        const SizedBox(height: AppSpacing.s10),
        _BillingStateNotice(status: status),
      ],
      const SizedBox(height: AppSpacing.xl),
      Text(
        status.isActive ? '更换会员方案' : '选择适合你的光',
        style: AppText.titleMedium.copyWith(color: theme.foreground),
      ),
      const SizedBox(height: AppSpacing.s3),
      Text(
        status.isActive && status.provider != 'apple'
            ? '微信与支付宝需在当前周期结束后切换方案。'
            : '所有已有内容都不会因会员到期被删除。',
        style: AppText.caption.copyWith(color: theme.foregroundMuted),
      ),
      const SizedBox(height: AppSpacing.s14),
      _BillingPeriodSwitch(value: period, onChanged: onPeriodChanged),
      const SizedBox(height: AppSpacing.s14),
      for (final tier in const [
        MembershipTier.starlight,
        MembershipTier.galaxy,
      ]) ...[
        _PlanCard(
          tier: tier,
          period: period,
          membership: status,
          products: status.products,
        ),
        const SizedBox(height: AppSpacing.s10),
      ],
      const _FreePlanNote(),
      const SizedBox(height: AppSpacing.lg),
      _SubscriptionActions(status: status),
      const SizedBox(height: AppSpacing.s14),
      Text(
        '年付新用户可试用 7 天。订阅会自动续费，可在原支付渠道管理或取消。'
        '数据导出、下载和删除始终免费。',
        style: AppText.caption.copyWith(color: theme.foregroundMuted),
      ),
    ]);
  }
}

class _CurrentMembershipPanel extends StatelessWidget {
  const _CurrentMembershipPanel({required this.status});

  final MembershipStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final membershipTheme = MembershipTheme.forTier(status.tier);
    final usedRatio = status.storageQuotaBytes <= 0
        ? 0.0
        : (status.storageUsedBytes / status.storageQuotaBytes).clamp(0.0, 1.0);
    final aiRemaining = (status.aiQuota - status.aiUsed).clamp(0, 999999);
    return XiguangCard(
      padding: const EdgeInsets.all(AppSpacing.s18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: membershipTheme.primary.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child:
                Icon(_tierIcon(status.tier), size: 20, color: theme.foreground),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('${status.tier.label}会员',
                      style: AppText.titleMedium
                          .copyWith(color: theme.foreground)),
                  if (status.isTrial) ...[
                    const SizedBox(width: AppSpacing.s6),
                    _StatusBadge(label: '体验中', color: membershipTheme.primary),
                  ],
                ]),
                const SizedBox(height: AppSpacing.s2),
                Text(_subscriptionText(status),
                    style:
                        AppText.caption.copyWith(color: theme.foregroundMuted)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.s18),
        Row(children: [
          Expanded(
            child: _UsageLabel(
              label: '云端空间',
              value: '${_bytes(status.storageUsedBytes)} / '
                  '${_bytes(status.storageQuotaBytes)}',
            ),
          ),
          if (status.aiQuota > 0) ...[
            const SizedBox(width: AppSpacing.s14),
            Expanded(
              child: _UsageLabel(
                label: '本周期 AI',
                value: '剩余 $aiRemaining 次',
              ),
            ),
          ],
        ]),
        const SizedBox(height: AppSpacing.s10),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: usedRatio,
            minHeight: 5,
            backgroundColor: theme.border.withValues(alpha: .55),
            valueColor: AlwaysStoppedAnimation<Color>(membershipTheme.primary),
          ),
        ),
      ]),
    );
  }
}

class _UsageLabel extends StatelessWidget {
  const _UsageLabel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: AppText.microLabel.copyWith(color: theme.foregroundMuted)),
      const SizedBox(height: AppSpacing.s3),
      Text(value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.captionStrong.copyWith(color: theme.foreground)),
    ]);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s6,
          vertical: AppSpacing.s2,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(label, style: AppText.microLabel.copyWith(color: color)),
      );
}

class _BillingPeriodSwitch extends StatelessWidget {
  const _BillingPeriodSwitch({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'month', label: Text('月付')),
          ButtonSegment(value: 'year', label: Text('年付 · 省更多')),
        ],
        selected: {value},
        onSelectionChanged: (selected) => onChanged(selected.single),
        showSelectedIcon: false,
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(theme.foreground),
          side: WidgetStatePropertyAll(BorderSide(color: theme.border)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({
    required this.tier,
    required this.period,
    required this.membership,
    required this.products,
  });

  final MembershipTier tier;
  final String period;
  final MembershipStatus membership;
  final List<BillingProduct> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = NightTheme.of(context);
    final membershipTheme = MembershipTheme.forTier(tier);
    final catalog = products
        .where((item) => item.tier == tier && item.period == period)
        .toList(growable: false);
    final enabled =
        catalog.where((item) => item.providerEnabled).toList(growable: false);
    final product = catalog.isEmpty ? null : catalog.first;
    final isCurrent = membership.tier == tier && membership.isActive;
    final benefits = tier == MembershipTier.starlight
        ? MembershipBenefits.starlight
        : MembershipBenefits.galaxy;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s18),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: theme.isNight ? .72 : .62),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isCurrent || tier == MembershipTier.starlight
              ? membershipTheme.primary.withValues(alpha: .72)
              : theme.border,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_tierIcon(tier), color: membershipTheme.primary, size: 21),
          const SizedBox(width: AppSpacing.s10),
          Text(tier.label,
              style: AppText.titleMedium.copyWith(color: theme.foreground)),
          const Spacer(),
          if (isCurrent)
            _StatusBadge(label: '当前方案', color: membershipTheme.primary)
          else if (tier == MembershipTier.starlight)
            _StatusBadge(label: '推荐', color: membershipTheme.primary),
        ]),
        const SizedBox(height: AppSpacing.s10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            product?.priceLabel ?? (period == 'year' ? '¥--' : '¥--'),
            style: AppText.titleLarge.copyWith(color: theme.foreground),
          ),
          const SizedBox(width: AppSpacing.s3),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s3),
            child: Text(
              period == 'year' ? '/年' : '/月',
              style: AppText.caption.copyWith(color: theme.foregroundMuted),
            ),
          ),
          if (period == 'year' && product != null) ...[
            const Spacer(),
            Text(
              '约 ¥${(product.priceCents / 1200).toStringAsFixed(1)}/月',
              style: AppText.caption.copyWith(color: theme.foregroundMuted),
            ),
          ],
        ]),
        if (period == 'year' && (product?.trialDays ?? 0) > 0) ...[
          const SizedBox(height: AppSpacing.s3),
          Text('新用户先试用 ${product!.trialDays} 天',
              style: AppText.captionStrong
                  .copyWith(color: membershipTheme.primary)),
        ],
        const SizedBox(height: AppSpacing.s14),
        for (final benefit in benefits.take(4))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(children: [
              Icon(Icons.check_rounded,
                  size: 17, color: membershipTheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(benefit.title,
                    style: AppText.caption.copyWith(color: theme.foreground)),
              ),
            ]),
          ),
        const SizedBox(height: AppSpacing.sm),
        if (isCurrent)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: null,
              child: const Text('当前正在使用'),
            ),
          )
        else if (enabled.isEmpty)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: null,
              child: const Text('支付渠道暂未开放'),
            ),
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final item in enabled)
                OutlinedButton.icon(
                  onPressed: _canPurchase(item)
                      ? () => _purchase(context, ref, item)
                      : null,
                  icon: Icon(_providerIcon(item.provider), size: 17),
                  label: Text('${_providerLabel(item.provider)}开通'),
                ),
            ],
          ),
      ]),
    );
  }

  bool _canPurchase(BillingProduct product) {
    if (!membership.isActive) return true;
    return membership.provider == 'apple' && product.provider == 'apple';
  }

  Future<void> _purchase(
    BuildContext context,
    WidgetRef ref,
    BillingProduct product,
  ) async {
    final trial = product.trialDays > 0 ? '，含 ${product.trialDays} 天试用' : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('开通 ${product.tier.label}'),
        content: Text('${product.priceLabel}/${product.periodLabel}$trial。'
            '到期将自动续费，可在${_providerLabel(product.provider)}管理或取消。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(membershipProvider.notifier).purchase(product);
    } catch (error) {
      if (context.mounted) _showPaymentError(context, error);
    }
  }
}

class _FreePlanNote extends StatelessWidget {
  const _FreePlanNote();

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return XiguangCard(
      padding: const EdgeInsets.all(AppSpacing.s14),
      child: Row(children: [
        Icon(Icons.wb_twilight_outlined, size: 19, color: theme.accent),
        const SizedBox(width: AppSpacing.s10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('微光永久免费',
                style: AppText.titleSmall.copyWith(color: theme.foreground)),
            const SizedBox(height: AppSpacing.s2),
            Text('核心记录、文字同步、1GB 空间和数据导出始终可用。',
                style: AppText.caption.copyWith(color: theme.foregroundMuted)),
          ]),
        ),
      ]),
    );
  }
}

class _SubscriptionActions extends ConsumerWidget {
  const _SubscriptionActions({required this.status});

  final MembershipStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(children: [
      if (Platform.isIOS) ...[
        XiguangButton(
          label: '恢复 App Store 购买',
          variant: XiguangButtonVariant.secondary,
          leading: const Icon(Icons.restore_rounded, size: 18),
          onPressed: () => _restore(context, ref),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      if (status.tier != MembershipTier.glimmer && !status.cancelAtPeriodEnd)
        XiguangButton(
          label: status.provider == 'apple' ? '管理订阅' : '停止自动续费',
          variant: XiguangButtonVariant.secondary,
          leading: const Icon(Icons.settings_outlined, size: 18),
          onPressed: () => _confirmCancel(context, ref),
        ),
    ]);
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(membershipProvider.notifier).restoreApple();
    } catch (error) {
      if (context.mounted) _showPaymentError(context, error);
    }
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final isApple = status.provider == 'apple';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isApple ? '管理订阅' : '停止自动续费'),
        content: Text(isApple
            ? '将打开 App Store 订阅管理。取消后，当前周期结束前仍可使用已有权益。'
            : '当前周期结束前仍可使用已有权益，之后回到微光。已有内容不会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('暂不处理'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(isApple ? '前往管理' : '停止续费'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(membershipProvider.notifier).cancel();
    } catch (error) {
      if (context.mounted) _showPaymentError(context, error);
    }
  }
}

class _BillingStateNotice extends StatelessWidget {
  const _BillingStateNotice({required this.status});

  final MembershipStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final (icon, text) = _content();
    return XiguangCard(
      padding: const EdgeInsets.all(AppSpacing.s14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: theme.accent),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text,
              style: AppText.caption.copyWith(color: theme.foregroundMuted)),
        ),
      ]),
    );
  }

  (IconData, String) _content() {
    if (status.pendingOrderStatus == 'pending') {
      return (Icons.hourglass_top_rounded, status.paymentMessage);
    }
    if (status.pendingOrderStatus == 'failed') {
      return (Icons.error_outline_rounded, status.paymentMessage);
    }
    if (status.pendingOrderStatus == 'canceled') {
      return (Icons.info_outline_rounded, status.paymentMessage);
    }
    if (status.status == 'grace' || status.status == 'past_due') {
      final until =
          status.graceUntil == null ? '' : '，宽限至 ${_date(status.graceUntil!)}';
      return (Icons.schedule_rounded, '续费扣款暂未成功$until。宽限期内权益保持不变。');
    }
    if (status.status == 'revoked') {
      return (Icons.currency_exchange_rounded, '该订阅已退款或撤销，账号已回到微光。');
    }
    return (Icons.event_busy_rounded, '订阅已经到期，已有内容仍可查看、导出和删除。');
  }
}

IconData _tierIcon(MembershipTier tier) => switch (tier) {
      MembershipTier.glimmer => Icons.wb_twilight_rounded,
      MembershipTier.starlight => Icons.star_rounded,
      MembershipTier.galaxy => Icons.auto_awesome_rounded,
    };

IconData _providerIcon(String provider) => switch (provider) {
      'apple' => Icons.apple_rounded,
      'wechat' => Icons.chat_bubble_outline_rounded,
      'alipay' => Icons.account_balance_wallet_outlined,
      _ => Icons.payment_rounded,
    };

String _providerLabel(String provider) => switch (provider) {
      'apple' => 'App Store',
      'wechat' => '微信',
      'alipay' => '支付宝',
      _ => '当前渠道',
    };

String _subscriptionText(MembershipStatus status) {
  if (status.tier == MembershipTier.glimmer) return '永久免费 · 核心记录与 1GB 空间';
  if (status.expiresAt == null) return status.providerLabel;
  final date = _date(status.expiresAt!);
  if (status.isTrial) return '试用至 $date';
  if (status.cancelAtPeriodEnd) return '已停止续费，可使用至 $date';
  return '${status.providerLabel} · $date 自动续费';
}

String _bytes(int value) {
  final gb = value / (1024 * 1024 * 1024);
  if (gb >= 1) {
    return gb == gb.roundToDouble()
        ? '${gb.round()}GB'
        : '${gb.toStringAsFixed(1)}GB';
  }
  return '${(value / (1024 * 1024)).round()}MB';
}

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

void _showPaymentError(BuildContext context, Object error) {
  final message =
      error is StateError ? error.message.toString() : '支付操作没有完成，请稍后再试。';
  showOverlaySnackBar(context, SnackBar(content: Text(message)));
}
