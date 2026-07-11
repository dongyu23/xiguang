// PAGE_SIZE_EXEMPT: migration in progress; account, privacy and settings sections will be separate feature widgets.
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';

import 'package:xiguang/app/app_state.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../sync/presentation/providers/sync_providers.dart';
import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../auth/domain/auth_session.dart';
import '../../../app_update/application/app_update_providers.dart';
import '../../../app_update/presentation/widgets/update_sheet.dart';
import '../../application/export_local_archive.dart';
import '../../domain/local_export_result.dart';
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
  bool _exporting = false;

  Future<void> _exportLocalArchive() async {
    if (_exporting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('导出本地记录'),
        content: const Text('将导出全部文字光片，并复制本地图片和声音到本机。可能需要一些时间。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('开始导出')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _exporting = true);
    try {
      final result = await ref.read(exportLocalArchiveProvider)();
      if (!mounted) return;
      _showExportResult(result);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('暂时无法导出本地记录。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _copyPath(String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('路径已复制'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openRecord(String markdownPath) async {
    try {
      await OpenFilex.open(markdownPath);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('无法打开记录文件。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showExportResult(LocalExportResult result) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = NightTheme.of(ctx);
        return XiguangBottomSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('本地导出完成',
                  style: AppText.titleLarge.copyWith(color: theme.foreground)),
              const SizedBox(height: AppSpacing.s10),
              Text(
                '已导出 ${result.fragmentCount} 束光、${result.mediaCount} 个本地媒体文件。',
                style: AppText.body.copyWith(color: theme.foreground),
              ),
              const SizedBox(height: AppSpacing.s12),
              SelectableText(
                result.directoryPath,
                style: AppText.caption.copyWith(color: theme.foregroundMuted),
              ),
              const SizedBox(height: AppSpacing.s18),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyPath(result.directoryPath),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('复制路径'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openRecord(result.markdownPath),
                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                    label: const Text('打开记录'),
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('知道了'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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
    final appearanceOption = ref.watch(nightModeOptionProvider);
    final compact = MediaQuery.sizeOf(context).width < 520;

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
                  // ── Header ──
                  Text('BOUNDARY',
                      style: AppText.eyebrow.copyWith(color: theme.accent)),
                  SizedBox(height: compact ? AppSpacing.s6 : AppSpacing.sm),
                  Text('我的',
                      style: AppText.hero.copyWith(color: theme.foreground)),
                  SizedBox(height: compact ? AppSpacing.s6 : AppSpacing.sm),
                  Text('账号、隐私和那些你想自己决定的边界。',
                      style: AppText.body.copyWith(color: theme.foreground)),
                  SizedBox(height: compact ? AppSpacing.s12 : AppSpacing.s22),

                  // ── 资料卡片 ──
                  _ProfileCard(
                    session: session,
                    compact: compact,
                    onTap: () => _showEditProfileSheet(context, session),
                  ),
                  SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),

                  // ── 账号 ──
                  const SettingsSectionLabel('账号'),
                  SizedBox(height: compact ? AppSpacing.s6 : AppSpacing.sm),
                  _FlatNavGroup(
                    compact: compact,
                    items: [
                      _NavItem(
                        icon: Icons.person_outline_rounded,
                        iconColor: AppColors.teaGreen,
                        label: '编辑资料',
                        subtitle: '昵称、密码',
                        onTap: () => _showEditProfileSheet(context, session),
                      ),
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
                        onTap: () => _showAbout(context),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? AppSpacing.s12 : AppSpacing.md),

                  // ── 连接与同步 ──
                  const SettingsSectionLabel('连接与同步'),
                  SizedBox(height: compact ? AppSpacing.s6 : AppSpacing.sm),
                  _FlatNavGroup(
                    compact: compact,
                    items: [
                      _NavItem(
                        icon: Icons.cloud_outlined,
                        iconColor: AppColors.mistBlue,
                        label: '云同步',
                        subtitle: '同步状态、连接参数、同步时机',
                        onTap: () => context.push('/sync-settings'),
                      ),
                      _NavItem(
                        icon: Icons.archive_outlined,
                        iconColor: AppColors.teaGreen,
                        label: _exporting ? '正在导出' : '导出本地记录',
                        subtitle: '导出文字，并复制本地图片和声音',
                        onTap: _exportLocalArchive,
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? AppSpacing.s12 : AppSpacing.md),

                  // ── 显示与外观 ──
                  const SettingsSectionLabel('显示与外观'),
                  SizedBox(height: compact ? AppSpacing.s6 : AppSpacing.sm),
                  _NightModeSelector(
                    currentOption: appearanceOption,
                    compact: compact,
                    onChanged: (option) => updateNightModeOption(ref, option),
                  ),
                  SizedBox(height: compact ? AppSpacing.s12 : AppSpacing.md),

                  // ── 氛围与心绪 ──
                  const SettingsSectionLabel('氛围与心绪'),
                  SizedBox(height: compact ? AppSpacing.s6 : AppSpacing.sm),
                  _FlatNavGroup(
                    compact: compact,
                    items: [
                      _NavItem(
                        icon: Icons.palette_outlined,
                        iconColor: AppColors.teaGreen,
                        label: '当前空间',
                        subtitle: '你现在的底色与氛围',
                        onTap: () => context.push('/space'),
                      ),
                      _NavItem(
                        icon: Icons.graphic_eq_rounded,
                        iconColor: AppColors.mistBlue,
                        label: '白噪音',
                        subtitle: '雨声、风声和一些轻轻托住注意力的声音',
                        onTap: () => context.push('/whitenoise'),
                      ),
                      _NavItem(
                        icon: Icons.palette_outlined,
                        iconColor: AppColors.lilac,
                        label: '管理心情',
                        subtitle: '编辑默认情绪、新增自定义感觉',
                        onTap: () => context.push('/emotions/manage'),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? AppSpacing.s12 : AppSpacing.md),

                  // ── 星图管理员 ──
                  const SettingsSectionLabel('星图管理员'),
                  SizedBox(height: compact ? AppSpacing.s6 : AppSpacing.sm),
                  _FlatNavGroup(
                    compact: compact,
                    items: [
                      _NavItem(
                        icon: Icons.auto_awesome_outlined,
                        iconColor: AppColors.lilac,
                        label: '柔光整理',
                        subtitle: '和星图管理员对话，看见光片之间的线',
                        onTap: () => context.push('/glow-organize'),
                      ),
                      _NavItem(
                        icon: Icons.explore_outlined,
                        iconColor: AppColors.teaGreen,
                        label: 'AI 建岛',
                        subtitle: '让星图管理员读光片，找出可以成岛的主题',
                        onTap: () => context.push('/ai/build-islands'),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? AppSpacing.s6 : AppSpacing.xs),
                  _AiToggleCard(session: session, compact: compact),
                  SizedBox(height: compact ? AppSpacing.s18 : AppSpacing.lg),

                  // ── 退出 ──
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: Icon(Icons.logout_rounded,
                          size: 16, color: AppColors.sunsetCoral),
                      label: Text('退出登录',
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

  // ── 编辑资料 BottomSheet（昵称 + 密码）──

  void _showEditProfileSheet(BuildContext context, AuthSession session) {
    final nicknameCtrl = TextEditingController(text: session.nickname);
    final oldPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    bool saving = false;
    String? errorText;
    bool showPasswordSection = false;
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
      if (nickname.isEmpty) {
        safeSetState(() => errorText = '昵称不能为空');
        return;
      }

      // 校验密码（如果填写了任意一个密码字段）
      final oldPw = oldPasswordCtrl.text;
      final newPw = newPasswordCtrl.text;
      final confirmPw = confirmPasswordCtrl.text;
      final wantsPasswordChange =
          oldPw.isNotEmpty || newPw.isNotEmpty || confirmPw.isNotEmpty;
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
        await ref.read(authActionsControllerProvider.notifier).updateProfile(
              nickname: nickname,
              avatarKey: session.avatarKey,
              aiEnabled: session.aiEnabled,
              privacyMode: session.privacyMode,
            );
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
            // 昵称已保存成功，仅密码修改失败
            safeSetState(() {
              saving = false;
              errorText = '资料已保存，但密码修改失败，请检查当前密码是否正确。';
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
              content: Text(passwordChanged ? '资料和密码已更新。' : '资料已更新。'),
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
                          child: Text('编辑资料',
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

                      // ── 昵称 ──
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

                      // ── 密码区域 ──
                      if (!showPasswordSection)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () =>
                                safeSetState(() => showPasswordSection = true),
                            icon: const Icon(Icons.lock_outline_rounded,
                                size: 16),
                            label: const Text('修改密码'),
                          ),
                        )
                      else ...[
                        Divider(height: 24, color: theme.border),
                        Text('修改密码',
                            style: AppText.titleSmall
                                .copyWith(color: theme.foreground)),
                        const SizedBox(height: AppSpacing.xs),
                        Text('留空则不修改密码。',
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
                          label: Text(saving ? '保存中...' : '保存'),
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

  // ── 关于隙光 ──

  void _showAbout(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = NightTheme.of(ctx);
        return XiguangBottomSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('隙光 v0.2',
                  style: AppText.titleLarge.copyWith(color: theme.foreground)),
              const SizedBox(height: AppSpacing.s12),
              Text(
                '私人多媒体碎片记录与回看工具。\n隙中捕光 → 光入成线 → 线间可织 → 织久成屿。\n\nAI 作为星图管理员辅助，不在后台分析，不替你解释。',
                style: AppText.bodyMuted.copyWith(color: theme.foregroundMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('知道了'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 私有组件
// ═══════════════════════════════════════════════════════════

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

/// 星图管理员开关 - 拨动即时生效，无需单独"保存"
class _AiToggleCard extends ConsumerStatefulWidget {
  const _AiToggleCard({required this.session, required this.compact});

  final AuthSession session;
  final bool compact;

  @override
  ConsumerState<_AiToggleCard> createState() => _AiToggleCardState();
}

class _AiToggleCardState extends ConsumerState<_AiToggleCard> {
  bool _saving = false;
  // 乐观本地值：null 表示跟随 session（权威值）
  bool? _localValue;
  bool get _value => _localValue ?? widget.session.aiEnabled;

  Future<void> _toggle(bool v) async {
    if (_saving || v == _value) return;
    setState(() {
      _saving = true;
      _localValue = v;
    });
    try {
      final updated = await ref
          .read(authActionsControllerProvider.notifier)
          .updateProfile(
            nickname: widget.session.nickname,
            avatarKey: widget.session.avatarKey,
            aiEnabled: v,
            privacyMode: widget.session.privacyMode,
          );
      ref.read(aiPolishEnabledProvider.notifier).state = updated.aiEnabled;
      if (mounted) {
        setState(() {
          _saving = false;
          _localValue = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _localValue = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('切换失败，请稍后再试'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return XiguangCard(
      padding: EdgeInsets.all(widget.compact ? AppSpacing.s14 : AppSpacing.md),
      child: SettingsSwitchRow(
        label: '启用星图管理员',
        subtitle: _value ? '已开启，只在主动触发时提供建议' : '已关闭',
        value: _value,
        onChanged: _saving ? null : _toggle,
      ),
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
