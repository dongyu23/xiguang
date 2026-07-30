import 'package:flutter/material.dart';

import '../../../design/tokens/colors.dart';

/// 会员等级 - 与隙光"光/星"隐喻一致。
///
/// 不做施压式会员体系：免费档（微光）保留全部已有功能，会员档只新增
/// 体验型权益（空间主题/白噪音/AI/存储），符合"柔软、不催促"的产品气质。
enum MembershipTier {
  /// 微光 - 免费档，默认。基础捕光 + 时间河流 + 小宇宙。
  glimmer('微光', 'glimmer'),

  /// 星光 - 会员档。20GB 存储 + 全部空间主题 + 专属白噪音 + 潮汐提示。
  starlight('星光', 'starlight'),

  /// 星河 - 至享档。星图管理员(AI) + 100GB 存储 + 星河氛围。
  galaxy('星河', 'galaxy');

  const MembershipTier(this.label, this.code);

  final String label;
  final String code;

  static MembershipTier fromCode(String code) {
    return MembershipTier.values.firstWhere(
      (t) => t.code == code,
      orElse: () => MembershipTier.glimmer,
    );
  }
}

class BillingProduct {
  const BillingProduct({
    required this.code,
    required this.tier,
    required this.period,
    required this.priceCents,
    required this.currency,
    required this.trialDays,
    required this.storageQuotaBytes,
    required this.aiQuota,
    required this.externalProductId,
    required this.provider,
    required this.providerEnabled,
    this.localizedPrice,
  });

  final String code;
  final MembershipTier tier;
  final String period;
  final int priceCents;
  final String currency;
  final int trialDays;
  final int storageQuotaBytes;
  final int aiQuota;
  final String externalProductId;
  final String provider;
  final bool providerEnabled;
  final String? localizedPrice;

  String get periodLabel => period == 'year' ? '年付' : '月付';
  String get priceLabel =>
      localizedPrice ?? '¥${(priceCents / 100).toStringAsFixed(0)}';

  BillingProduct copyWith({String? localizedPrice}) {
    return BillingProduct(
      code: code,
      tier: tier,
      period: period,
      priceCents: priceCents,
      currency: currency,
      trialDays: trialDays,
      storageQuotaBytes: storageQuotaBytes,
      aiQuota: aiQuota,
      externalProductId: externalProductId,
      provider: provider,
      providerEnabled: providerEnabled,
      localizedPrice: localizedPrice ?? this.localizedPrice,
    );
  }

  factory BillingProduct.fromJson(Map<String, dynamic> json) {
    return BillingProduct(
      code: json['code'] as String? ?? '',
      tier: MembershipTier.fromCode(json['tier'] as String? ?? ''),
      period: json['period'] as String? ?? 'month',
      priceCents: (json['price_cents'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'CNY',
      trialDays: (json['trial_days'] as num?)?.toInt() ?? 0,
      storageQuotaBytes: (json['storage_quota_bytes'] as num?)?.toInt() ?? 0,
      aiQuota: (json['ai_quota'] as num?)?.toInt() ?? 0,
      externalProductId: json['external_product_id'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      providerEnabled: json['provider_enabled'] as bool? ?? false,
      localizedPrice: json['localized_price'] as String?,
    );
  }
}

/// 服务端签发的会员状态；客户端不具备自行开通或延长权益的能力。
class MembershipStatus {
  const MembershipStatus({
    this.tier = MembershipTier.glimmer,
    this.expiresAt,
    this.graceUntil,
    this.status = 'active',
    this.provider = '',
    this.productCode = '',
    this.subscriptionId = '',
    this.cancelAtPeriodEnd = false,
    this.storageQuotaBytes = 1073741824,
    this.storageUsedBytes = 0,
    this.aiQuota = 0,
    this.aiUsed = 0,
    this.version = 1,
    this.pendingOrderStatus = '',
    this.paymentMessage = '',
    this.products = const [],
  });

  final MembershipTier tier;

  final DateTime? expiresAt;
  final DateTime? graceUntil;
  final String status;
  final String provider;
  final String productCode;
  final String subscriptionId;
  final bool cancelAtPeriodEnd;
  final int storageQuotaBytes;
  final int storageUsedBytes;
  final int aiQuota;
  final int aiUsed;
  final int version;
  final String pendingOrderStatus;
  final String paymentMessage;
  final List<BillingProduct> products;

  bool get isTrial => status == 'trialing';

  String get providerLabel => switch (provider) {
        'apple' => 'App Store',
        'wechat' => '微信',
        'alipay' => '支付宝',
        _ => '其他渠道',
      };

  MembershipStatus copyWith({
    List<BillingProduct>? products,
    String? pendingOrderStatus,
    String? paymentMessage,
  }) {
    return MembershipStatus(
      tier: tier,
      expiresAt: expiresAt,
      graceUntil: graceUntil,
      status: status,
      provider: provider,
      productCode: productCode,
      subscriptionId: subscriptionId,
      cancelAtPeriodEnd: cancelAtPeriodEnd,
      storageQuotaBytes: storageQuotaBytes,
      storageUsedBytes: storageUsedBytes,
      aiQuota: aiQuota,
      aiUsed: aiUsed,
      version: version,
      pendingOrderStatus: pendingOrderStatus ?? this.pendingOrderStatus,
      paymentMessage: paymentMessage ?? this.paymentMessage,
      products: products ?? this.products,
    );
  }

  bool get isActive {
    if (tier == MembershipTier.glimmer) return false;
    final now = DateTime.now();
    if (status == 'trialing' || status == 'active') {
      return expiresAt == null || expiresAt!.isAfter(now);
    }
    if (status == 'past_due' || status == 'grace') {
      return graceUntil?.isAfter(now) ??
          (expiresAt == null || expiresAt!.isAfter(now));
    }
    return false;
  }

  factory MembershipStatus.fromJson(
    Map<String, dynamic> json, {
    required List<BillingProduct> products,
  }) {
    DateTime? date(String key) => DateTime.tryParse(json[key] as String? ?? '');
    return MembershipStatus(
      tier: MembershipTier.fromCode(json['tier'] as String? ?? ''),
      expiresAt: date('valid_until'),
      graceUntil: date('grace_until'),
      status: json['status'] as String? ?? 'active',
      provider: json['provider'] as String? ?? '',
      productCode: json['product_code'] as String? ?? '',
      subscriptionId: json['subscription_id'] as String? ?? '',
      cancelAtPeriodEnd: json['cancel_at_period_end'] as bool? ?? false,
      storageQuotaBytes:
          (json['storage_quota_bytes'] as num?)?.toInt() ?? 1073741824,
      storageUsedBytes: (json['storage_used_bytes'] as num?)?.toInt() ?? 0,
      aiQuota: (json['ai_quota'] as num?)?.toInt() ?? 0,
      aiUsed: (json['ai_used'] as num?)?.toInt() ?? 0,
      version: (json['version'] as num?)?.toInt() ?? 1,
      products: List.unmodifiable(products),
    );
  }
}

/// 单条权益描述。
class MembershipBenefit {
  const MembershipBenefit({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

/// 各等级权益清单 - 前端静态配置，不依赖后端。
class MembershipBenefits {
  const MembershipBenefits._();

  static const glimmer = <MembershipBenefit>[
    MembershipBenefit(
      icon: Icons.camera_alt_outlined,
      title: '基础捕光',
      description: '文字与图片光片，随时轻轻放进宇宙。',
    ),
    MembershipBenefit(
      icon: Icons.timeline_outlined,
      title: '时间河流',
      description: '回看每一天散落的光，按情绪与标签筛选。',
    ),
    MembershipBenefit(
      icon: Icons.auto_awesome_outlined,
      title: '小宇宙视图',
      description: '主题星点与小岛，看见光之间的联系。',
    ),
    MembershipBenefit(
      icon: Icons.cloud_outlined,
      title: '1GB 永久空间',
      description: '基础云端空间与设备同步，已有内容不会因到期被删除。',
    ),
  ];

  static const starlight = <MembershipBenefit>[
    MembershipBenefit(
      icon: Icons.all_inclusive_outlined,
      title: '20GB 云端空间',
      description: '为图片与声音留出更宽松、边界清晰的空间。',
    ),
    MembershipBenefit(
      icon: Icons.wb_cloudy_outlined,
      title: '全部空间主题',
      description: '星空、海洋、岛屿，随心切换沉浸氛围。',
    ),
    MembershipBenefit(
      icon: Icons.graphic_eq_outlined,
      title: '专属白噪音',
      description: '雨声、翻书、风声、心跳，扩展音频库。',
    ),
    MembershipBenefit(
      icon: Icons.waves_outlined,
      title: '潮汐提示',
      description: '情绪与主题的来去，被温柔地看见。',
    ),
  ];

  static const galaxy = <MembershipBenefit>[
    MembershipBenefit(
      icon: Icons.auto_fix_high_outlined,
      title: '星图管理员',
      description: 'AI 柔光整理，轻轻命名、帮你织线、不解释你。',
    ),
    MembershipBenefit(
      icon: Icons.bolt_outlined,
      title: '每月 300 次 AI',
      description: '成功完成的柔光整理与星图建议才计入次数。',
    ),
    MembershipBenefit(
      icon: Icons.diamond_outlined,
      title: '星河专属氛围',
      description: '深空色调与专属徽章，属于星河的痕迹。',
    ),
    MembershipBenefit(
      icon: Icons.download_for_offline_outlined,
      title: '100GB 云端空间',
      description: '给长期积累的图片与声音留出更大的位置。',
    ),
  ];

  static List<MembershipBenefit> forTier(MembershipTier tier) {
    switch (tier) {
      case MembershipTier.glimmer:
        return glimmer;
      case MembershipTier.starlight:
        return [...glimmer, ...starlight];
      case MembershipTier.galaxy:
        return [...glimmer, ...starlight, ...galaxy];
    }
  }
}

/// 各等级的视觉标识 - 渐变色 + 主色 + 副色，用于会员卡与徽章。
class MembershipTheme {
  const MembershipTheme({
    required this.primary,
    required this.accent,
    required this.gradient,
    required this.foreground,
    required this.tagline,
  });

  final Color primary;
  final Color accent;
  final LinearGradient gradient;
  final Color foreground;
  final String tagline;

  static const _glimmer = MembershipTheme(
    primary: AppColors.teaGreen,
    accent: AppColors.emotionUnclear,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.paper, AppColors.white, AppColors.cardBorder],
    ),
    foreground: AppColors.ink,
    tagline: '隙中捕光，慢慢来。',
  );

  static const _starlight = MembershipTheme(
    primary: AppColors.lilac,
    accent: AppColors.emotionHappy,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.lilac, AppColors.emotionChaos, AppColors.emotionHappy],
    ),
    foreground: AppColors.ink,
    tagline: '让每一束光，都被长久安放。',
  );

  static const _galaxy = MembershipTheme(
    primary: AppColors.mistBlue,
    accent: AppColors.nightInkMuted,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppColors.nightCardDark,
        AppColors.nightSurface,
        AppColors.nightInkMuted
      ],
    ),
    foreground: AppColors.nightInk,
    tagline: '深空之间，星图管理员陪你回看。',
  );

  static MembershipTheme forTier(MembershipTier tier) {
    switch (tier) {
      case MembershipTier.glimmer:
        return _glimmer;
      case MembershipTier.starlight:
        return _starlight;
      case MembershipTier.galaxy:
        return _galaxy;
    }
  }
}
