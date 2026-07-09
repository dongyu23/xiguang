import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../app_update/presentation/providers/app_update_providers.dart';
import '../../../app_update/presentation/widgets/update_sheet.dart';
import '../../data/local_archive_exporter.dart';
import '../../../../ui/composites/settings_widgets.dart';
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
    setState(() => _exporting = true);
    try {
      final fragments =
          await ref.read(fragmentRepositoryProvider).listFragments();
      final result =
          await const LocalArchiveExporter().exportFragments(fragments);
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: result.directoryPath));
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

  void _showExportResult(LocalExportResult result) {
    final nightMode = ref.read(nightModeProvider);
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.s18),
          padding: const EdgeInsets.all(AppSpacing.s22),
          decoration:
              nightMode ? nightDecoration() : softDecoration(AppColors.white),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('本地导出完成',
                  style: AppText.onNight(AppText.titleLarge, nightMode)),
              const SizedBox(height: AppSpacing.s10),
              Text(
                '已导出 ${result.fragmentCount} 束光、${result.mediaCount} 个本地媒体文件。导出目录路径已复制。',
                style: AppText.onNight(AppText.body, nightMode),
              ),
              const SizedBox(height: AppSpacing.s12),
              SelectableText(
                result.directoryPath,
                style: AppText.onNight(AppText.caption, nightMode),
              ),
              const SizedBox(height: AppSpacing.s18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('知道了'),
                ),
              ),
            ],
          ),
        ),
      ),
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
    await ref.read(authRepositoryProvider).logout();
    ref.read(authSessionProvider.notifier).state = null;
    ref.invalidate(sessionProvider);
    // 重置同步状态为未连接，避免退出后 banner 显示陈旧的"已连接"；
    // 重新登录后 authSessionProvider listener 会重新 checkConnection 刷新。
    ref.invalidate(syncStatusProvider);
    if (!mounted) return;
    GoRouter.of(context).go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final sessionValue = ref.watch(sessionProvider);
    final nightMode = ref.watch(nightModeProvider);
    final nightModeOption = ref.watch(nightModeOptionProvider);
    final compact = MediaQuery.sizeOf(context).width < 520;

    return Stack(children: [
      // C2: Background now provided by _AppShell in router.dart
      SafeArea(
        child: ScrollToTop(
          builder: (context, controller) => SingleChildScrollView(
            controller: controller,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              compact ? 18 : 22,
              compact ? 10 : 18,
              compact ? 18 : 22,
              64 + 10 + MediaQuery.paddingOf(context).bottom + 40,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: sessionValue.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => _ErrorPanel(nightMode: nightMode),
                  data: (session) {
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Header ──
                          Text('BOUNDARY',
                              style:
                                  AppText.onNight(AppText.eyebrow, nightMode)),
                          SizedBox(
                              height: compact ? AppSpacing.s6 : AppSpacing.sm),
                          Row(children: [
                            Expanded(
                                child: Text('我的',
                                    style: AppText.onNight(
                                        AppText.hero, nightMode))),
                            // 夜间模式状态指示图标
                            Icon(
                              nightMode
                                  ? Icons.nights_stay_outlined
                                  : Icons.wb_sunny_outlined,
                              color: nightMode
                                  ? AppColors.emotionHappy
                                  : AppColors.inkMuted,
                              size: 20,
                            ),
                          ]),
                          SizedBox(
                              height: compact ? AppSpacing.s6 : AppSpacing.sm),
                          Text('账号、隐私和那些你想自己决定的边界。',
                              style: AppText.onNight(AppText.body, nightMode)),
                          SizedBox(
                              height:
                                  compact ? AppSpacing.s12 : AppSpacing.s22),

                          // ── 资料卡片 ──
                          _ProfileCard(
                            session: session,
                            nightMode: nightMode,
                            compact: compact,
                          ),
                          SizedBox(
                              height: compact ? AppSpacing.md : AppSpacing.lg),

                          // ── 星图管理员 ──
                          _SectionLabel('星图管理员', nightMode: nightMode),
                          SizedBox(
                              height: compact ? AppSpacing.s6 : AppSpacing.sm),
                          _FlatNavGroup(
                            nightMode: nightMode,
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
                              _NavItem(
                                icon: Icons.tune_rounded,
                                iconColor: AppColors.inkMuted,
                                label: '星图管理员设置',
                                subtitle: session.aiEnabled
                                    ? '已开启，只在主动触发时提供建议'
                                    : '已关闭',
                                onTap: () => _showAiToggleSheet(
                                    context, session, nightMode),
                              ),
                            ],
                          ),
                          SizedBox(
                              height: compact ? AppSpacing.s12 : AppSpacing.md),

                          // ── 空间与氛围 ──
                          _SectionLabel('空间与氛围', nightMode: nightMode),
                          SizedBox(
                              height: compact ? AppSpacing.s6 : AppSpacing.sm),
                          _FlatNavGroup(
                            nightMode: nightMode,
                            compact: compact,
                            items: [
                              _NavItem(
                                icon: Icons.palette_outlined,
                                iconColor: AppColors.teaGreen,
                                label: '空间主题',
                                subtitle: '查看当前空间的底色和氛围描述',
                                onTap: () => context.push('/space'),
                              ),
                              _NavItem(
                                icon: Icons.graphic_eq_rounded,
                                iconColor: AppColors.mistBlue,
                                label: '白噪音',
                                subtitle: '雨声、风声和一些轻轻托住注意力的声音',
                                onTap: () => context.push('/whitenoise'),
                              ),
                            ],
                          ),
                          SizedBox(
                              height: compact ? AppSpacing.s12 : AppSpacing.md),

                          // ── 显示与外观 ──
                          _SectionLabel('显示与外观', nightMode: nightMode),
                          SizedBox(
                              height: compact ? AppSpacing.s6 : AppSpacing.sm),
                          _NightModeSelector(
                            currentOption: nightModeOption,
                            nightMode: nightMode,
                            compact: compact,
                            onChanged: (option) =>
                                updateNightModeOption(ref, option),
                          ),
                          SizedBox(
                              height: compact ? AppSpacing.s12 : AppSpacing.md),

                          // ── 心绪 ──
                          _SectionLabel('心绪', nightMode: nightMode),
                          SizedBox(
                              height: compact ? AppSpacing.s6 : AppSpacing.sm),
                          _FlatNavGroup(
                            nightMode: nightMode,
                            compact: compact,
                            items: [
                              _NavItem(
                                icon: Icons.palette_outlined,
                                iconColor: AppColors.lilac,
                                label: '管理心情',
                                subtitle: '编辑默认情绪、新增自定义感觉',
                                onTap: () => context.push('/emotions/manage'),
                              ),
                            ],
                          ),
                          SizedBox(
                              height: compact ? AppSpacing.s12 : AppSpacing.md),

                          // ── 连接与同步 ──
                          _SectionLabel('连接与同步', nightMode: nightMode),
                          SizedBox(
                              height: compact ? AppSpacing.s6 : AppSpacing.sm),
                          _FlatNavGroup(
                            nightMode: nightMode,
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
                          SizedBox(
                              height: compact ? AppSpacing.s12 : AppSpacing.md),

                          // ── 账号 ──
                          _SectionLabel('账号', nightMode: nightMode),
                          SizedBox(
                              height: compact ? AppSpacing.s6 : AppSpacing.sm),
                          _FlatNavGroup(
                            nightMode: nightMode,
                            compact: compact,
                            items: [
                              _NavItem(
                                icon: Icons.person_outline_rounded,
                                iconColor: AppColors.teaGreen,
                                label: '编辑资料',
                                subtitle: '昵称、密码',
                                onTap: () =>
                                    _showEditProfileSheet(context, session),
                              ),
                              _NavItem(
                                icon: Icons.system_update_alt_rounded,
                                iconColor: AppColors.mistBlue,
                                label: '检查更新',
                                subtitle: ref.watch(appUpdateBadgeProvider)
                                    ? '· 发现可用的新版本'
                                    : '查看是否有新版可用',
                                onTap: () => showAppUpdateSheet(context),
                              ),
                              _NavItem(
                                icon: Icons.info_outline_rounded,
                                iconColor: AppColors.inkMuted,
                                label: '关于隙光',
                                subtitle: '版本信息和产品说明',
                                onTap: () => _showAbout(context, nightMode),
                              ),
                            ],
                          ),
                          SizedBox(
                              height: compact ? AppSpacing.s18 : AppSpacing.lg),

                          // ── 退出 ──
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _logout,
                              icon: Icon(Icons.logout_rounded,
                                  size: 16, color: AppColors.sunsetCoral),
                              label: Text('退出登录',
                                  style: TextStyle(
                                      color: AppColors.sunsetCoral,
                                      fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.sunsetCoral,
                                disabledForegroundColor:
                                    AppColors.sunsetCoral.withValues(alpha: .38),
                                side: BorderSide(
                                  color: AppColors.sunsetCoral
                                      .withValues(alpha: .42),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.s13),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                ),
                              ),
                            ),
                          ),
                        ]);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  // ── 编辑资料 BottomSheet（昵称 + 密码）──

  void _showEditProfileSheet(BuildContext context, AuthSession session) {
    final nightMode = ref.read(nightModeProvider);
    final nicknameCtrl = TextEditingController(text: session.nickname);
    final oldPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    bool saving = false;
    String? errorText;
    bool showPasswordSection = false;
    BuildContext? sheetCtx;
    bool sheetDisposed = false; // sheet 关闭后,所有异步 setSheetState 必须跳过

    Future<void> save(StateSetter setSheetState) async {
      // sheet 已 dispose（用户拖关），直接放弃后续 UI 更新
      void safeSetState(VoidCallback fn) {
        if (sheetDisposed) return;
        if (sheetCtx == null || !sheetCtx!.mounted) return;
        setSheetState(fn);
      }

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
        final updated = await ref.read(authRepositoryProvider).updateMe(
              nickname: nickname,
              avatarKey: session.avatarKey,
              aiEnabled: session.aiEnabled,
              privacyMode: session.privacyMode,
            );
        if (sheetDisposed) return; // 拉关 sheet 后保存还在跑，直接放弃
        ref.read(authSessionProvider.notifier).state = updated;
        ref.invalidate(sessionProvider);

        bool passwordChanged = false;
        if (wantsPasswordChange) {
          try {
            await ref.read(authRepositoryProvider).changePassword(
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
      // 禁用拖拽关闭：sheet 内有 TextField，拖关时 onChanged/setState 会引用
      // 已 dispose 的 StatefulBuilder 触发黑屏。改为只能点关闭按钮或点遮罩关闭。
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (builderCtx) {
        sheetCtx = builderCtx;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            return SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(
                    AppSpacing.s18, 0, AppSpacing.s18, AppSpacing.s18),
                padding: EdgeInsets.fromLTRB(22, 20, 22, 22 + bottomInset),
                decoration: nightMode
                    ? nightDecoration()
                    : softDecoration(AppColors.white),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text('编辑资料',
                              style: AppText.onNight(
                                  AppText.titleLarge, nightMode)),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: nightMode
                                  ? AppText.nightInkMuted
                                  : AppColors.inkMuted),
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
                            setSheetState(() => errorText = null);
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
                                setSheetState(() => showPasswordSection = true),
                            icon: const Icon(Icons.lock_outline_rounded,
                                size: 16),
                            label: const Text('修改密码'),
                          ),
                        )
                      else ...[
                        Divider(
                            height: 24,
                            color: nightMode
                                ? AppColors.white.withValues(alpha: .10)
                                : AppColors.line),
                        Text('修改密码',
                            style:
                                AppText.onNight(AppText.titleSmall, nightMode)),
                        const SizedBox(height: AppSpacing.xs),
                        Text('留空则不修改密码。',
                            style: AppText.onNight(AppText.caption, nightMode)),
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
                              setSheetState(() => errorText = null);
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
                              setSheetState(() => errorText = null);
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        TextField(
                          controller: confirmPasswordCtrl,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => save(setSheetState),
                          decoration: const InputDecoration(
                            labelText: '确认新密码',
                          ),
                          onChanged: (_) {
                            if (errorText != null) {
                              setSheetState(() => errorText = null);
                            }
                          },
                        ),
                      ],

                      // ── 错误提示 ──
                      if (errorText != null) ...[
                        const SizedBox(height: AppSpacing.s12),
                        Text(errorText!,
                            style: AppText.onNight(AppText.caption, nightMode)
                                .copyWith(color: AppColors.sunsetCoral)),
                      ],

                      const SizedBox(height: AppSpacing.s20),

                      // ── 保存按钮 ──
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: saving ? null : () => save(setSheetState),
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

  // ── AI 开关 BottomSheet ──

  void _showAiToggleSheet(
      BuildContext context, AuthSession session, bool nightMode) {
    bool aiEnabled = session.aiEnabled;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(
                    AppSpacing.s18, 0, AppSpacing.s18, AppSpacing.s18),
                padding: const EdgeInsets.fromLTRB(AppSpacing.s22,
                    AppSpacing.s20, AppSpacing.s22, AppSpacing.s22),
                decoration: nightMode
                    ? nightDecoration()
                    : softDecoration(AppColors.white),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text('星图管理员',
                            style: AppText.onNight(
                                AppText.titleLarge, nightMode)),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: nightMode
                                ? AppText.nightInkMuted
                                : AppColors.inkMuted),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ]),
                    const SizedBox(height: AppSpacing.md),
                    SettingsSwitchRow(
                      label: '启用星图管理员',
                      subtitle: '开启后，只在你主动触发时提供建议。不在后台分析你的光片。',
                      value: aiEnabled,
                      nightMode: nightMode,
                      onChanged: saving
                          ? null
                          : (v) => setSheetState(() => aiEnabled = v),
                    ),
                    const SizedBox(height: AppSpacing.s20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                setSheetState(() => saving = true);
                                try {
                                  final updated = await ref
                                      .read(authRepositoryProvider)
                                      .updateMe(
                                        nickname: session.nickname,
                                        avatarKey: session.avatarKey,
                                        aiEnabled: aiEnabled,
                                        privacyMode: session.privacyMode,
                                      );
                                  ref.read(authSessionProvider.notifier).state =
                                      updated;
                                  ref
                                      .read(aiPolishEnabledProvider.notifier)
                                      .state = updated.aiEnabled;
                                  ref.invalidate(sessionProvider);
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                } catch (_) {
                                  setSheetState(() => saving = false);
                                }
                              },
                        child: Text(saving ? '保存中...' : '保存'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── 关于隙光 ──

  void _showAbout(BuildContext context, bool nightMode) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.s18),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration:
              nightMode ? nightDecoration() : softDecoration(AppColors.white),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('隙光 v0.2',
                  style: AppText.onNight(AppText.titleLarge, nightMode)),
              const SizedBox(height: AppSpacing.s12),
              Text(
                '私人多媒体碎片记录与回看工具。\n隙中捕光 → 光入成线 → 线间可织 → 织久成屿。\n\nAI 作为星图管理员辅助，不在后台分析，不替你解释。',
                style: AppText.onNight(AppText.bodyMuted, nightMode),
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
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 私有组件
// ═══════════════════════════════════════════════════════════

/// 分组标签
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {required this.nightMode});
  final String label;
  final bool nightMode;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: AppSpacing.s2, bottom: 0),
        child: Text(label, style: AppText.onNight(AppText.eyebrow, nightMode)),
      );
}

/// 资料卡片 — 只读展示
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.session,
    required this.nightMode,
    required this.compact,
  });

  final AuthSession session;
  final bool nightMode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      nightMode: nightMode,
      compact: compact,
      children: [
        Row(children: [
          Container(
            width: compact ? 42 : 52,
            height: compact ? 42 : 52,
            decoration: BoxDecoration(
                color: AppColors.teaGreen.withValues(alpha: .22),
                borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Icon(Icons.person_outline_rounded,
                color: nightMode ? AppColors.white : AppColors.ink),
          ),
          SizedBox(width: compact ? AppSpacing.s10 : AppSpacing.s14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(session.nickname,
                  style: AppText.onNight(AppText.titleMedium, nightMode)),
              const SizedBox(height: AppSpacing.s3),
              Text('@${session.username}',
                  style: AppText.onNight(AppText.caption, nightMode)),
            ]),
          ),
        ]),
        SizedBox(height: compact ? AppSpacing.s10 : AppSpacing.s14),
        SettingsInfoRow(
            label: '用户名',
            value: session.username,
            nightMode: nightMode,
            compact: compact),
      ],
    );
  }
}

class _FlatNavGroup extends StatelessWidget {
  const _FlatNavGroup({
    required this.nightMode,
    required this.compact,
    required this.items,
  });

  final bool nightMode;
  final bool compact;
  final List<_NavItem> items;

  @override
  Widget build(BuildContext context) {
    final dividerColor = nightMode
        ? AppColors.white.withValues(alpha: .08)
        : AppColors.line.withValues(alpha: .60);
    return Container(
      decoration:
          nightMode ? nightDecoration() : softDecoration(AppColors.white),
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
              nightMode: nightMode,
              compact: compact,
              onTap: items[i].onTap,
            ),
          ),
          if (i < items.length - 1)
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: compact ? AppSpacing.s12 : AppSpacing.md),
              child: Divider(height: 1, color: dividerColor),
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

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.nightMode});
  final bool nightMode;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.s18),
        decoration:
            nightMode ? nightDecoration() : softDecoration(AppColors.white),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('账号状态暂时不可用',
              style: AppText.onNight(AppText.titleMedium, nightMode)),
          const SizedBox(height: AppSpacing.s10),
          Text('可以重新登录，或检查后端连接。',
              style: AppText.onNight(AppText.body, nightMode)),
        ]),
      );
}

/// 夜间模式选择器 — 三选一：跟随系统 / 日间 / 夜间
class _NightModeSelector extends StatelessWidget {
  const _NightModeSelector({
    required this.currentOption,
    required this.nightMode,
    required this.compact,
    required this.onChanged,
  });

  final NightModeOption currentOption;
  final bool nightMode;
  final bool compact;
  final ValueChanged<NightModeOption> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? AppSpacing.s14 : AppSpacing.md),
      decoration:
          nightMode ? nightDecoration() : softDecoration(AppColors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.brightness_6_outlined,
                size: 18,
                color: nightMode ? AppColors.emotionHappy : AppColors.teaGreen),
            const SizedBox(width: AppSpacing.sm),
            Text('深色模式', style: AppText.onNight(AppText.titleSmall, nightMode)),
          ]),
          const SizedBox(height: AppSpacing.s12),
          _buildOptionRow(
            icon: Icons.brightness_auto_outlined,
            label: '跟随系统',
            subtitle: '白天日间，夜晚自动切换',
            option: NightModeOption.system,
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildOptionRow(
            icon: Icons.wb_sunny_outlined,
            label: '日间模式',
            subtitle: '始终使用明亮色调',
            option: NightModeOption.light,
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildOptionRow(
            icon: Icons.nights_stay_outlined,
            label: '夜间模式',
            subtitle: '始终使用柔和暗色',
            option: NightModeOption.dark,
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
  }) {
    final isSelected = currentOption == option;
    final selectedColor = nightMode ? AppColors.teaGreen : AppColors.teaGreen;
    final unselectedColor =
        nightMode ? AppText.nightInkMuted : AppColors.inkMuted;

    return InkWell(
      onTap: () => onChanged(option),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12, vertical: AppSpacing.s10),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: nightMode ? .18 : .10)
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
                      color: isSelected
                          ? (nightMode ? AppColors.white : AppColors.ink)
                          : unselectedColor,
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
