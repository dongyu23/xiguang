import 'package:flutter/material.dart';

import '../../design/themes/extensions/night_theme.dart';
import '../../design/tokens/radius.dart';
import '../../design/tokens/spacing.dart';
import '../../design/tokens/typography.dart';
import 'xiguang_card.dart';

/// 设置页/我的页通用卡片 — 日间 softDecoration / 夜间 nightDecoration
class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.children,
    this.compact = false,
    this.onTap,
  });

  final List<Widget> children;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => XiguangCard(
        onTap: onTap,
        padding: EdgeInsets.all(
          compact ? AppSpacing.widgetPadding : AppSpacing.s18,
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

/// 设置页分组标签 — eyebrow 风格
class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.s2),
      child: Text(
        label,
        style: AppText.eyebrow.copyWith(color: theme.foregroundMuted),
      ),
    );
  }
}

/// 设置页信息行 — label 固定宽 + value
class SettingsInfoRow extends StatelessWidget {
  const SettingsInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label, value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: compact ? AppSpacing.s7 : AppSpacing.s10),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            SizedBox(
                width: 56,
                child: Text(label,
                    style: AppText.caption
                        .copyWith(color: theme.foregroundMuted))),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(color: theme.foreground),
              ),
            ),
          ]),
    );
  }
}

/// 设置页开关行 — label + subtitle + Switch
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.prominent = true,
  });

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Semantics(
      button: true,
      enabled: onChanged != null,
      toggled: value,
      label: label,
      hint: subtitle,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: onChanged == null ? null : () => onChanged!(!value),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: (prominent ? AppText.titleSmall : AppText.body)
                              .copyWith(color: theme.foreground)),
                      const SizedBox(height: AppSpacing.xs),
                      Text(subtitle,
                          style: AppText.caption
                              .copyWith(color: theme.foregroundMuted)),
                    ]),
              ),
              Switch.adaptive(value: value, onChanged: onChanged),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 设置页导航行 — icon + label + chevron，点击跳转
class SettingsNavRow extends StatelessWidget {
  const SettingsNavRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.compact,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
            vertical: compact ? AppSpacing.s6 : AppSpacing.sm),
        child: Row(children: [
          Container(
            width: compact ? 36 : 40,
            height: compact ? 36 : 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: .20),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, size: 18, color: theme.foreground),
          ),
          SizedBox(width: compact ? AppSpacing.s10 : AppSpacing.s12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: AppText.titleSmall.copyWith(color: theme.foreground)),
              SizedBox(height: compact ? AppSpacing.s2 : AppSpacing.xs),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppText.caption.copyWith(color: theme.foregroundMuted)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: theme.foregroundMuted),
        ]),
      ),
    );
  }
}
