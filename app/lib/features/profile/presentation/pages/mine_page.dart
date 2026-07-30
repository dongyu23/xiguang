// PAGE_SIZE_EXEMPT: migration in progress; account, privacy and settings sections will be separate feature widgets.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:xiguang/app/app_state.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../membership/application/membership_controller.dart';
import '../../../membership/domain/membership.dart';
import '../../../sync/presentation/providers/sync_providers.dart';
import '../../../sync/presentation/providers/sync_provider.dart';
import '../../../sync/domain/sync_config.dart';
import '../../../sync/domain/sync_status.dart';
import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/motion.dart';
import '../../../auth/domain/auth_session.dart';
import '../../../app_update/application/app_update_providers.dart';
import '../../../app_update/presentation/widgets/update_sheet.dart';
import '../../../../ui/composites/settings_widgets.dart';
import '../../../../ui/composites/xiguang_bottom_sheet.dart';
import '../../../../ui/composites/xiguang_card.dart';
import '../../../../ui/composites/xiguang_empty_state.dart';
import '../../../../ui/composites/xiguang_page.dart';
import '../../../../ui/primitives/scroll_to_top.dart';

/// 我的页 — 分组设置入口 + 资料卡片。
class MinePage extends ConsumerStatefulWidget {
  const MinePage({super.key});

  @override
  ConsumerState<MinePage> createState() => _MinePageState();
}

class _MinePageState extends ConsumerState<MinePage> {
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('退出后需要重新登录才能查看光片。确定退出吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.sunsetCoral,
                foregroundColor: AppColors.white,
              ),
              child: const Text('退出')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authActionsControllerProvider.notifier).logout();
    // 重置同步状态为未连接，避免退出后 banner 显示陈旧的"已连接"；
    // 重新登录后 authSessionProvider listener 会重新 checkConnection 刷新。
    ref.invalidate(syncStatusProvider);
    if (!mounted) return;
    GoRouter.of(context).go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final sessionValue = ref.watch(sessionProvider);
    final theme = NightTheme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 520;
    final membership = ref.watch(membershipProvider).valueOrNull;

    return ScrollToTop(
      builder: (context, controller) => XiguangPage(
        scrollController: controller,
        padding: EdgeInsets.fromLTRB(
          compact ? AppSpacing.s18 : AppSpacing.s22,
          compact ? AppSpacing.s10 : AppSpacing.s18,
          compact ? AppSpacing.s18 : AppSpacing.s22,
          AppSpacing.pageBottomNav +
              AppSpacing.s10 +
              MediaQuery.paddingOf(context).bottom,
        ),
        child: sessionValue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const _ErrorPanel(),
          data: (session) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('我的',
                      style:
                          AppText.titleLarge.copyWith(color: theme.foreground)),
                  const SizedBox(height: AppSpacing.s3),
                  Text('账号、会员与应用边界',
                      style: AppText.caption
                          .copyWith(color: theme.foregroundMuted)),
                  SizedBox(height: compact ? AppSpacing.s14 : AppSpacing.s18),

                  _ProfileCard(
                    session: session,
                    compact: compact,
                    onTap: () => _showEditProfileSheet(context, session),
                  ),
                  const SizedBox(height: AppSpacing.s10),
                  _MembershipEntryCard(
                    status: membership,
                    compact: compact,
                    onTap: () => context.push('/membership'),
                  ),
                  SizedBox(height: compact ? AppSpacing.s18 : AppSpacing.lg),

                  const SettingsSectionLabel('账号'),
                  SizedBox(height: compact ? AppSpacing.s6 : AppSpacing.sm),
                  _FlatNavGroup(
                    compact: compact,
                    items: [
                      _NavItem(
                        icon: Icons.lock_outline_rounded,
                        iconColor: AppColors.teaGreen,
                        label: '修改密码',
                        subtitle: '更新登录凭据',
                        onTap: () => _showEditProfileSheet(
                          context,
                          session,
                          passwordOnly: true,
                        ),
                      ),
                      _NavItem(
                        icon: Icons.shield_outlined,
                        iconColor: AppColors.mistBlue,
                        label: '隐私与账号安全',
                        subtitle: '数据边界、注销与账号删除',
                        onTap: () => context.push('/privacy-settings'),
                      ),
                      _NavItem(
                        icon: Icons.devices_outlined,
                        iconColor: AppColors.lilac,
                        label: '登录设备',
                        subtitle: '查看当前登录并退出其他设备',
                        onTap: () => context.push('/devices'),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? AppSpacing.s18 : AppSpacing.lg),

                  const SettingsSectionLabel('设置'),
                  SizedBox(height: compact ? AppSpacing.s6 : AppSpacing.sm),
                  _FlatNavGroup(
                    compact: compact,
                    items: [
                      _NavItem(
                        icon: Icons.tune_rounded,
                        iconColor: AppColors.teaGreen,
                        label: '记录与体验',
                        subtitle: '外观、提醒、声音、潮汐与 AI',
                        onTap: () => context.push('/experience-settings'),
                      ),
                      _NavItem(
                        icon: Icons.cloud_outlined,
                        iconColor: AppColors.mistBlue,
                        label: '数据与同步',
                        subtitle: '云同步、归档、回收站与存储',
                        onTap: () => context.push('/data-settings'),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? AppSpacing.s18 : AppSpacing.lg),

                  const SettingsSectionLabel('应用'),
                  SizedBox(height: compact ? AppSpacing.s6 : AppSpacing.sm),
                  _FlatNavGroup(
                    compact: compact,
                    items: [
                      _NavItem(
                        icon: Icons.system_update_alt_rounded,
                        iconColor: AppColors.mistBlue,
                        label: '检查更新',
                        subtitle: ref.watch(appUpdateBadgeProvider)
                            ? '发现可用的新版本'
                            : '查看是否有新版可用',
                        onTap: () => showAppUpdateSheet(context),
                      ),
                      _NavItem(
                        icon: Icons.info_outline_rounded,
                        iconColor: AppColors.inkMuted,
                        label: '关于隙光',
                        subtitle: '版本信息和产品说明',
                        onTap: () => context.push('/about'),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? AppSpacing.s18 : AppSpacing.xl),

                  // ── 退出 ──
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: Icon(Icons.logout_rounded,
                          size: 16, color: AppColors.sunsetCoral),
                      label: Text('退出当前账号',
                          style: AppText.bodyStrong
                              .copyWith(color: AppColors.sunsetCoral)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.sunsetCoral,
                        disabledForegroundColor:
                            AppColors.sunsetCoral.withValues(alpha: .38),
                        side: BorderSide(
                          color: AppColors.sunsetCoral.withValues(alpha: .42),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.s13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                  ),
                ]);
          },
        ),
      ),
    );
  }

  // ── 编辑资料 / 修改密码 BottomSheet ──

  void _showEditProfileSheet(
    BuildContext context,
    AuthSession session, {
    bool passwordOnly = false,
  }) {
    final nicknameCtrl = TextEditingController(text: session.nickname);
    final oldPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    bool saving = false;
    String? errorText;
    BuildContext? sheetCtx;
    StateSetter? currentSetState; // 在 builder 中捕获，供 safeSetState 使用
    bool sheetDisposed = false; // sheet 关闭后,所有异步 setSheetState 必须跳过

    // sheet 已 dispose（用户拖关或点遮罩关闭），直接放弃后续 UI 更新
    void safeSetState(VoidCallback fn) {
      if (sheetDisposed) return;
      if (sheetCtx == null || !sheetCtx!.mounted) return;
      currentSetState!(fn);
    }

    Future<void> save() async {
      final nickname = nicknameCtrl.text.trim();
      if (!passwordOnly && nickname.isEmpty) {
        safeSetState(() => errorText = '昵称不能为空');
        return;
      }

      // 修改密码入口始终要求完整填写三个字段。
      final oldPw = oldPasswordCtrl.text;
      final newPw = newPasswordCtrl.text;
      final confirmPw = confirmPasswordCtrl.text;
      final wantsPasswordChange = passwordOnly;
      if (wantsPasswordChange) {
        if (oldPw.isEmpty || newPw.isEmpty) {
          safeSetState(() => errorText = '请填写当前密码和新密码');
          return;
        }
        if (newPw.length < 6) {
          safeSetState(() => errorText = '新密码至少需要 6 个字符');
          return;
        }
        if (newPw != confirmPw) {
          safeSetState(() => errorText = '两次输入的新密码不一致');
          return;
        }
        if (newPw == oldPw) {
          safeSetState(() => errorText = '新密码不能和当前密码相同');
          return;
        }
      }

      safeSetState(() {
        saving = true;
        errorText = null;
      });
      try {
        if (!passwordOnly) {
          await ref.read(authActionsControllerProvider.notifier).updateProfile(
                nickname: nickname,
                avatarKey: session.avatarKey,
                aiEnabled: session.aiEnabled,
                privacyMode: session.privacyMode,
              );
        }
        if (sheetDisposed) return; // 拉关 sheet 后保存还在跑，直接放弃
        bool passwordChanged = false;
        if (wantsPasswordChange) {
          try {
            await ref
                .read(authActionsControllerProvider.notifier)
                .changePassword(
                  oldPassword: oldPw,
                  newPassword: newPw,
                );
            passwordChanged = true;
          } catch (_) {
            safeSetState(() {
              saving = false;
              errorText = '密码修改失败，请检查当前密码是否正确。';
            });
            return;
          }
        }

        if (!sheetDisposed && sheetCtx != null && sheetCtx!.mounted) {
          Navigator.of(sheetCtx!).pop();
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(passwordOnly
                  ? '密码已更新。'
                  : passwordChanged
                      ? '资料和密码已更新。'
                      : '资料已更新。'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (_) {
        safeSetState(() {
          saving = false;
          errorText = '保存失败，请稍后再试';
        });
      }
    }

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      // 允许拖拽关闭：所有 setSheetState 已通过 safeSetState 守卫，
      // 拖关后 sheetDisposed 标记会短路异步更新，避免引用已 dispose 的 StatefulBuilder。
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (builderCtx) {
        sheetCtx = builderCtx;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            currentSetState = setSheetState;
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            final theme = NightTheme.of(ctx);
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: XiguangBottomSheet(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(passwordOnly ? '修改密码' : '编辑资料',
                              style: AppText.titleLarge
                                  .copyWith(color: theme.foreground)),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: theme.foregroundMuted),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ]),
                      const SizedBox(height: AppSpacing.s18),

                      if (!passwordOnly) ...[
                        TextField(
                          controller: nicknameCtrl,
                          textInputAction: TextInputAction.next,
                          maxLength: 32,
                          decoration: const InputDecoration(
                            labelText: '昵称',
                            hintText: '给自己取一个温柔的名字',
                          ),
                          onChanged: (_) {
                            if (errorText != null) {
                              safeSetState(() => errorText = null);
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.s6),
                      ],

                      if (passwordOnly) ...[
                        Text('修改密码',
                            style: AppText.titleSmall
                                .copyWith(color: theme.foreground)),
                        const SizedBox(height: AppSpacing.xs),
                        Text('输入当前密码，并设置一个至少 6 位的新密码。',
                            style: AppText.caption
                                .copyWith(color: theme.foregroundMuted)),
                        const SizedBox(height: AppSpacing.s12),
                        TextField(
                          controller: oldPasswordCtrl,
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: '当前密码',
                          ),
                          onChanged: (_) {
                            if (errorText != null) {
                              safeSetState(() => errorText = null);
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        TextField(
                          controller: newPasswordCtrl,
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: '新密码',
                          ),
                          onChanged: (_) {
                            if (errorText != null) {
                              safeSetState(() => errorText = null);
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        TextField(
                          controller: confirmPasswordCtrl,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => save(),
                          decoration: const InputDecoration(
                            labelText: '确认新密码',
                          ),
                          onChanged: (_) {
                            if (errorText != null) {
                              safeSetState(() => errorText = null);
                            }
                          },
                        ),
                      ],

                      // ── 错误提示 ──
                      if (errorText != null) ...[
                        const SizedBox(height: AppSpacing.s12),
                        Text(errorText!,
                            style:
                                AppText.caption.copyWith(color: theme.danger)),
                      ],

                      const SizedBox(height: AppSpacing.s20),

                      // ── 保存按钮 ──
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: saving ? null : () => save(),
                          icon: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 18),
                          label: Text(
                            saving
                                ? '保存中...'
                                : passwordOnly
                                    ? '更新密码'
                                    : '保存资料',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      sheetDisposed = true; // 标记后所有 safeSetState 自动短路
      nicknameCtrl.dispose();
      oldPasswordCtrl.dispose();
      newPasswordCtrl.dispose();
      confirmPasswordCtrl.dispose();
    });
  }
}

/// 我的页的二级数据目录。首屏只展示一个总入口，低频操作在这里展开。
class DataSettingsOverviewPage extends ConsumerStatefulWidget {
  const DataSettingsOverviewPage({super.key});

  @override
  ConsumerState<DataSettingsOverviewPage> createState() =>
      _DataSettingsOverviewPageState();
}

class _DataSettingsOverviewPageState
    extends ConsumerState<DataSettingsOverviewPage> {
  bool _syncing = false;

  void _updateSyncConfig(SyncConfig config) {
    ref.read(syncConfigProvider.notifier).update(config);
    ref.read(syncEngineProvider).updateConfig(config);
  }

  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final status = await syncManually(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status.error != null
              ? '同步失败，请检查网络和后端状态。'
              : status.pendingCount == 0
                  ? '同步完成。'
                  : '同步完成，仍有 ${status.pendingCount} 条待推送。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('同步失败，请检查网络和后端状态。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 520;
    final syncConfig = ref.watch(syncConfigProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    return XiguangPage(
      padding: EdgeInsets.fromLTRB(
        compact ? AppSpacing.s18 : AppSpacing.s22,
        AppSpacing.s10,
        compact ? AppSpacing.s18 : AppSpacing.s22,
        AppSpacing.pageBottomNav + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SettingsPageHeader(
          title: '数据与同步',
          subtitle: '管理云端连接、本地空间与完整归档。',
        ),
        const SizedBox(height: AppSpacing.s18),
        _InlineSyncCard(
          config: syncConfig,
          status: syncStatus,
          compact: compact,
          syncing: _syncing,
          onConfigChanged: _updateSyncConfig,
          onSyncNow: _syncNow,
          onOpenDetails: () => context.push('/sync-settings'),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SettingsSectionLabel('数据管理'),
        const SizedBox(height: AppSpacing.s6),
        _FlatNavGroup(
          compact: compact,
          items: [
            _NavItem(
              icon: Icons.archive_outlined,
              iconColor: AppColors.teaGreen,
              label: '数据归档',
              subtitle: '完整导出、校验与安全恢复',
              onTap: () => context.push('/data-archive'),
            ),
            _NavItem(
              icon: Icons.restore_from_trash_outlined,
              iconColor: AppColors.mistBlue,
              label: '回收站',
              subtitle: '恢复误删的光片',
              onTap: () => context.push('/trash'),
            ),
            _NavItem(
              icon: Icons.cleaning_services_outlined,
              iconColor: AppColors.inkMuted,
              label: '存储与缓存',
              subtitle: '查看用量并清理临时文件',
              onTap: () => context.push('/storage-settings'),
            ),
          ],
        ),
      ]),
    );
  }
}

/// 与记录体验有关的低频设置，和账号、数据边界分开组织。
class ExperienceSettingsPage extends ConsumerWidget {
  const ExperienceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = MediaQuery.sizeOf(context).width < 520;
    final appearance = ref.watch(nightModeOptionProvider);
    final aiEnabled = ref.watch(aiEnabledProvider);
    final session = ref.watch(sessionProvider);
    return XiguangPage(
      padding: EdgeInsets.fromLTRB(
        compact ? AppSpacing.s18 : AppSpacing.s22,
        AppSpacing.s10,
        compact ? AppSpacing.s18 : AppSpacing.s22,
        AppSpacing.pageBottomNav + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SettingsPageHeader(
          title: '记录与体验',
          subtitle: '调整隙光回应你的方式，不改变已有内容。',
        ),
        const SizedBox(height: AppSpacing.s18),
        const SettingsSectionLabel('外观'),
        const SizedBox(height: AppSpacing.s6),
        _NightModeSelector(
          currentOption: appearance,
          compact: compact,
          onChanged: (option) => updateNightModeOption(ref, option),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SettingsSectionLabel('记录与回看'),
        const SizedBox(height: AppSpacing.s6),
        _FlatNavGroup(
          compact: compact,
          items: [
            _NavItem(
              icon: Icons.notifications_none_rounded,
              iconColor: AppColors.mistBlue,
              label: '柔光提醒',
              subtitle: '捕光、旧光回访和小岛静默',
              onTap: () => context.push('/reminders'),
            ),
            _NavItem(
              icon: Icons.layers_outlined,
              iconColor: AppColors.teaGreen,
              label: '空间与氛围',
              subtitle: '当前空间、主题与视觉底色',
              onTap: () => context.push('/space'),
            ),
            _NavItem(
              icon: Icons.graphic_eq_rounded,
              iconColor: AppColors.mistBlue,
              label: '白噪音',
              subtitle: '雨声、翻书声与会员声音',
              onTap: () => context.push('/whitenoise'),
            ),
            _NavItem(
              icon: Icons.waves_rounded,
              iconColor: AppColors.teaGreen,
              label: '潮汐提示',
              subtitle: '回看近期反复出现的感受',
              onTap: () => context.push('/tide-insight'),
            ),
            _NavItem(
              icon: Icons.mood_outlined,
              iconColor: AppColors.lilac,
              label: '心情与织线',
              subtitle: '管理情绪词与关系类型',
              onTap: () => context.push('/emotions/manage'),
            ),
            _NavItem(
              icon: Icons.route_outlined,
              iconColor: AppColors.mistBlue,
              label: '织线类型',
              subtitle: '编辑默认关系或新增自定义联系',
              onTap: () => context.push('/relations/types/manage'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const SettingsSectionLabel('星图管理员'),
        const SizedBox(height: AppSpacing.s6),
        session.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const _ErrorPanel(),
          data: (value) => _AiToggleCard(session: value, compact: compact),
        ),
        AnimatedSize(
          duration: AppMotion.normal,
          curve: AppMotion.easeOut,
          alignment: Alignment.topCenter,
          child: aiEnabled
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s6),
                  child: _FlatNavGroup(
                    compact: compact,
                    items: [
                      _NavItem(
                        icon: Icons.auto_awesome_outlined,
                        iconColor: AppColors.lilac,
                        label: '柔光整理',
                        subtitle: '总结选中的光片、岛或一段时间',
                        onTap: () => context.push('/glow-organize'),
                      ),
                      _NavItem(
                        icon: Icons.hub_outlined,
                        iconColor: AppColors.teaGreen,
                        label: '岛群建议',
                        subtitle: '查看可以聚在一起的岛屿候选',
                        onTap: () => context.push('/ai/island-groups'),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}

class _SettingsPageHeader extends StatelessWidget {
  const _SettingsPageHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      IconButton(
        tooltip: '返回',
        visualDensity: VisualDensity.compact,
        onPressed: () => Navigator.of(context).maybePop(),
        icon: Icon(Icons.arrow_back_rounded, color: theme.foreground),
      ),
      const SizedBox(height: AppSpacing.s6),
      Text(title, style: AppText.titleLarge.copyWith(color: theme.foreground)),
      const SizedBox(height: AppSpacing.s3),
      Text(subtitle,
          style: AppText.caption.copyWith(color: theme.foregroundMuted)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════
// 私有组件
// ═══════════════════════════════════════════════════════════

class _MembershipEntryCard extends StatelessWidget {
  const _MembershipEntryCard({
    required this.status,
    required this.compact,
    required this.onTap,
  });

  final MembershipStatus? status;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final membership = status ?? const MembershipStatus();
    final membershipTheme = MembershipTheme.forTier(membership.tier);
    final isFree = membership.tier == MembershipTier.glimmer;
    final storage = _storageSummary(membership);
    final aiRemaining =
        (membership.aiQuota - membership.aiUsed).clamp(0, 999999);
    return Semantics(
      button: true,
      label: '隙光会员，当前${membership.tier.label}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Ink(
            padding: EdgeInsets.all(compact ? AppSpacing.s14 : AppSpacing.s18),
            decoration: BoxDecoration(
              color: membershipTheme.primary
                  .withValues(alpha: theme.isNight ? .20 : .13),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: membershipTheme.primary.withValues(alpha: .42),
              ),
            ),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: membershipTheme.primary.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  membership.tier == MembershipTier.galaxy
                      ? Icons.auto_awesome_rounded
                      : membership.tier == MembershipTier.starlight
                          ? Icons.star_rounded
                          : Icons.wb_twilight_rounded,
                  color: theme.foreground,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(
                        '${membership.tier.label}会员',
                        style: AppText.titleSmall
                            .copyWith(color: theme.foreground),
                      ),
                      if (membership.isTrial) ...[
                        const SizedBox(width: AppSpacing.s6),
                        Text('体验中',
                            style: AppText.microLabel
                                .copyWith(color: membershipTheme.primary)),
                      ],
                    ]),
                    const SizedBox(height: AppSpacing.s3),
                    Text(
                      isFree
                          ? '1GB 永久空间 · 查看会员方案'
                          : membership.aiQuota > 0
                              ? '$storage · AI 剩余 $aiRemaining 次'
                              : '$storage · ${membership.cancelAtPeriodEnd ? '到期后回到微光' : '自动续费中'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption
                          .copyWith(color: theme.foregroundMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.foregroundMuted),
            ]),
          ),
        ),
      ),
    );
  }

  String _storageSummary(MembershipStatus value) {
    final used = value.storageUsedBytes / (1024 * 1024 * 1024);
    final total = value.storageQuotaBytes / (1024 * 1024 * 1024);
    final usedLabel = used < .1
        ? '${(used * 1024).round()}MB'
        : '${used.toStringAsFixed(1)}GB';
    return '$usedLabel / ${total.round()}GB';
  }
}

/// 资料卡片 — 点击进入编辑
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.session,
    required this.compact,
    required this.onTap,
  });

  final AuthSession session;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return SettingsCard(
      compact: compact,
      onTap: onTap,
      children: [
        Row(children: [
          Container(
            width: compact ? 42 : 52,
            height: compact ? 42 : 52,
            decoration: BoxDecoration(
                color: AppColors.teaGreen.withValues(alpha: .22),
                borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Icon(Icons.person_outline_rounded, color: theme.foreground),
          ),
          SizedBox(width: compact ? AppSpacing.s10 : AppSpacing.s14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(session.nickname,
                  style: AppText.titleMedium.copyWith(color: theme.foreground)),
              const SizedBox(height: AppSpacing.s3),
              Text('@${session.username}',
                  style:
                      AppText.caption.copyWith(color: theme.foregroundMuted)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: theme.foregroundMuted),
        ]),
      ],
    );
  }
}

class _InlineSyncCard extends StatelessWidget {
  const _InlineSyncCard({
    required this.config,
    required this.status,
    required this.compact,
    required this.syncing,
    required this.onConfigChanged,
    required this.onSyncNow,
    required this.onOpenDetails,
  });

  final SyncConfig config;
  final SyncStatus status;
  final bool compact;
  final bool syncing;
  final ValueChanged<SyncConfig> onConfigChanged;
  final VoidCallback onSyncNow;
  final VoidCallback onOpenDetails;

  String get _lastSyncLabel {
    final value = status.lastSyncAt;
    if (value == null) return '尚未同步';
    final now = DateTime.now();
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    if (value.year == now.year &&
        value.month == now.month &&
        value.day == now.day) {
      return '今天 $time';
    }
    return '${value.month}月${value.day}日 $time';
  }

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final connectedColor = status.connected ? theme.accent : theme.danger;
    final statusLabel = status.connected ? '已连接' : '未连接';
    return XiguangCard(
      padding: EdgeInsets.all(compact ? AppSpacing.s14 : AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: theme.accent.withValues(alpha: theme.isNight ? .18 : .10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.cloud_outlined, size: 19, color: theme.accent),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('云同步',
                    style:
                        AppText.titleSmall.copyWith(color: theme.foreground)),
                const SizedBox(height: AppSpacing.s2),
                Text(
                    config.enabled
                        ? '$statusLabel · $_lastSyncLabel'
                        : '自动同步已关闭 · 本地变更会保留',
                    style:
                        AppText.caption.copyWith(color: theme.foregroundMuted)),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: connectedColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.s6),
          Switch.adaptive(
            value: config.enabled,
            onChanged: (value) =>
                onConfigChanged(config.copyWith(enabled: value)),
          ),
        ]),
        const SizedBox(height: AppSpacing.s12),
        Row(children: [
          Expanded(
            child: Opacity(
              opacity: config.enabled ? 1 : .46,
              child: _CompactSyncSetting(
                label: '同步时机',
                child: PopupMenuButton<SyncFrequency>(
                  tooltip: '选择同步时机',
                  enabled: config.enabled,
                  initialValue: config.frequency,
                  onSelected: (value) =>
                      onConfigChanged(config.copyWith(frequency: value)),
                  itemBuilder: (_) => [
                    for (final frequency in SyncFrequency.automaticValues)
                      PopupMenuItem(
                        value: frequency,
                        child: Text(frequency.label),
                      ),
                  ],
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(
                      child: Text(
                        config.frequency.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppText.caption.copyWith(color: theme.foreground),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s2),
                    Icon(Icons.expand_more_rounded,
                        size: 17, color: theme.foregroundMuted),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Opacity(
              opacity: config.enabled ? 1 : .46,
              child: _CompactSyncSetting(
                label: '自动同步仅 Wi-Fi',
                child: Switch.adaptive(
                  value: config.enabled && config.wifiOnly,
                  onChanged: config.enabled
                      ? (value) =>
                          onConfigChanged(config.copyWith(wifiOnly: value))
                      : null,
                ),
              ),
            ),
          ),
        ]),
        if (status.pendingCount > 0) ...[
          const SizedBox(height: AppSpacing.s10),
          Text('有 ${status.pendingCount} 条本地修改等待同步',
              style: AppText.caption.copyWith(color: theme.foregroundMuted)),
        ],
        const SizedBox(height: AppSpacing.s12),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onOpenDetails,
              child: const Text('同步详情'),
            ),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: FilledButton.icon(
              onPressed: status.connected && !syncing ? onSyncNow : null,
              icon: syncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync_rounded, size: 17),
              label: Text(syncing ? '同步中' : '立即同步'),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _CompactSyncSetting extends StatelessWidget {
  const _CompactSyncSetting({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: theme.isNight ? .62 : .72),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.border.withValues(alpha: .72)),
      ),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: AppText.caption.copyWith(color: theme.foregroundMuted)),
        ),
        child,
      ]),
    );
  }
}

class _FlatNavGroup extends StatelessWidget {
  const _FlatNavGroup({
    required this.compact,
    required this.items,
  });

  final bool compact;
  final List<_NavItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return XiguangCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var i = 0; i < items.length; i++) ...[
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? AppSpacing.s12 : AppSpacing.md,
              vertical: compact ? AppSpacing.s2 : AppSpacing.xs,
            ),
            child: SettingsNavRow(
              icon: items[i].icon,
              iconColor: items[i].iconColor,
              label: items[i].label,
              subtitle: items[i].subtitle,
              compact: compact,
              onTap: items[i].onTap,
            ),
          ),
          if (i < items.length - 1)
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? AppSpacing.s12 : AppSpacing.md),
              child: Divider(
                height: 1,
                color: theme.border.withValues(alpha: .60),
              ),
            ),
        ],
      ]),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
}

/// 星图管理员开关 - 总闸。关闭时所有 AI 入口消失。
/// 首次开启弹数据外发同意弹窗（只弹一次），后续开关直接生效。
class _AiToggleCard extends ConsumerStatefulWidget {
  const _AiToggleCard({required this.session, required this.compact});

  final AuthSession session;
  final bool compact;

  @override
  ConsumerState<_AiToggleCard> createState() => _AiToggleCardState();
}

class _AiToggleCardState extends ConsumerState<_AiToggleCard> {
  bool _saving = false;
  String? _consentAcceptedAt;

  @override
  void initState() {
    super.initState();
    _consentAcceptedAt = widget.session.aiConsentAcceptedAt;
  }

  @override
  void didUpdateWidget(covariant _AiToggleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.aiConsentAcceptedAt !=
        widget.session.aiConsentAcceptedAt) {
      _consentAcceptedAt = widget.session.aiConsentAcceptedAt;
    }
  }

  Future<void> _toggle(bool v) async {
    if (_saving || v == ref.read(aiEnabledProvider)) return;

    // 首次开启：弹数据外发同意弹窗（只弹一次）
    final needsConsent = v && _consentAcceptedAt == null;
    if (needsConsent) {
      final accepted = await _showConsentDialog();
      if (!accepted || !mounted) return;
    }

    setState(() => _saving = true);
    // 乐观更新总开关，父级立即展开/收起子入口
    ref.read(aiEnabledProvider.notifier).state = v;
    try {
      final updated =
          await ref.read(authActionsControllerProvider.notifier).updateProfile(
                nickname: widget.session.nickname,
                avatarKey: widget.session.avatarKey,
                aiEnabled: v,
                aiConsentAccepted: needsConsent,
                privacyMode: widget.session.privacyMode,
              );
      ref.read(aiEnabledProvider.notifier).state = updated.aiEnabled;
      _consentAcceptedAt = updated.aiConsentAcceptedAt;
    } catch (_) {
      ref.read(aiEnabledProvider.notifier).state = !v;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('切换失败，请稍后再试'),
            behavior: SnackBarBehavior.floating,
            duration: AppMotion.snackbar,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _showConsentDialog({bool reviewOnly = false}) async {
    return (await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final theme = NightTheme.of(ctx);
            return AlertDialog(
              backgroundColor: theme.surface,
              title: Text(
                reviewOnly ? '星图管理员数据说明' : '开启星图管理员',
                style: AppText.titleLarge.copyWith(color: theme.foreground),
              ),
              content: SingleChildScrollView(
                child: Text(
                  '开启后，只有当你主动使用柔光整理、AI 建岛或润色时，'
                  '相关光片的文字、情绪和标签才会发送至 DeepSeek 进行分析。\n\n'
                  '星图管理员不会在后台主动读取光片，也不会替你解释或判断情绪。\n\n'
                  '你可以随时关闭。关闭后所有 AI 入口会隐藏，已有光片和整理结果不受影响。',
                  style: AppText.body.copyWith(color: theme.foreground),
                ),
              ),
              actions: reviewOnly
                  ? [
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('知道了'),
                      ),
                    ]
                  : [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('暂不开启'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('同意并开启'),
                      ),
                    ],
            );
          },
        )) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(aiEnabledProvider);
    return XiguangCard(
      padding: EdgeInsets.all(widget.compact ? AppSpacing.s14 : AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SettingsSwitchRow(
          label: '启用星图管理员',
          subtitle: enabled ? '已开启 · 仅在你主动使用时发送数据' : '已关闭',
          value: enabled,
          onChanged: _saving ? null : _toggle,
        ),
        const SizedBox(height: AppSpacing.s6),
        TextButton.icon(
          onPressed:
              _saving ? null : () => _showConsentDialog(reviewOnly: true),
          icon: const Icon(Icons.shield_outlined, size: 16),
          label: const Text('数据使用说明'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6),
            minimumSize: const Size(0, 36),
          ),
        ),
      ]),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel();

  @override
  Widget build(BuildContext context) => const XiguangEmptyState(
        title: '账号状态暂时不可用',
        description: '可以重新登录，或检查后端连接。',
        icon: Icons.cloud_off_outlined,
      );
}

/// 夜间模式选择器 — 三选一：跟随系统 / 日间 / 夜间
class _NightModeSelector extends StatelessWidget {
  const _NightModeSelector({
    required this.currentOption,
    required this.compact,
    required this.onChanged,
  });

  final NightModeOption currentOption;
  final bool compact;
  final ValueChanged<NightModeOption> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return XiguangCard(
      padding: EdgeInsets.all(compact ? AppSpacing.s14 : AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.brightness_6_outlined, size: 18, color: theme.accent),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '深色模式',
              style: AppText.titleSmall.copyWith(color: theme.foreground),
            ),
          ]),
          const SizedBox(height: AppSpacing.s12),
          _buildOptionRow(
            icon: Icons.brightness_auto_outlined,
            label: '跟随系统',
            subtitle: '白天日间，夜晚自动切换',
            option: NightModeOption.system,
            theme: theme,
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildOptionRow(
            icon: Icons.wb_sunny_outlined,
            label: '日间模式',
            subtitle: '始终使用明亮色调',
            option: NightModeOption.light,
            theme: theme,
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildOptionRow(
            icon: Icons.nights_stay_outlined,
            label: '夜间模式',
            subtitle: '始终使用柔和暗色',
            option: NightModeOption.dark,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required NightModeOption option,
    required NightTheme theme,
  }) {
    final isSelected = currentOption == option;
    final selectedColor = theme.accent;
    final unselectedColor = theme.foregroundMuted;

    return InkWell(
      onTap: () => onChanged(option),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12, vertical: AppSpacing.s10),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: theme.isNight ? .18 : .10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected
                ? selectedColor.withValues(alpha: .40)
                : Colors.transparent,
          ),
        ),
        child: Row(children: [
          Icon(icon,
              size: 18, color: isSelected ? selectedColor : unselectedColor),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: (isSelected ? AppText.bodyStrong : AppText.body)
                        .copyWith(
                      color: isSelected ? theme.foreground : unselectedColor,
                    )),
                const SizedBox(height: AppSpacing.s2),
                Text(subtitle,
                    style: AppText.caption.copyWith(
                      color: isSelected
                          ? selectedColor.withValues(alpha: .80)
                          : unselectedColor.withValues(alpha: .70),
                    )),
              ],
            ),
          ),
          if (isSelected)
            Icon(Icons.check_rounded, size: 18, color: selectedColor),
        ]),
      ),
    );
  }
}
