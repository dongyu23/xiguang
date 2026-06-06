import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../ui/composites/night_mode_button.dart';
import '../../../../ui/spaces/space_canvas.dart';

/// 我的页 — 所有账号、AI、同步、隐私、关于统一放在这里。
class MinePage extends ConsumerStatefulWidget {
  const MinePage({super.key});

  @override
  ConsumerState<MinePage> createState() => _MinePageState();
}

class _MinePageState extends ConsumerState<MinePage> {
  final _nickname = TextEditingController();
  bool _editing = false;
  bool _saving = false;
  bool _savingAiPolish = false;
  bool? _aiEnabledDraft;
  String? _notice;

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  void _enterEdit(AuthSession session) {
    _nickname.text = session.nickname;
    setState(() {
      _editing = true;
      _aiEnabledDraft = session.aiEnabled;
      _notice = null;
    });
  }

  Future<void> _saveProfile(AuthSession session) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _notice = null;
    });
    try {
      final updated = await ref.read(authRepositoryProvider).updateMe(
            nickname: _nickname.text.trim(),
            avatarKey: session.avatarKey,
            aiEnabled: _aiEnabledDraft ?? ref.read(aiPolishEnabledProvider),
            privacyMode: session.privacyMode,
          );
      ref.read(authSessionProvider.notifier).state = updated;
      ref.read(aiPolishEnabledProvider.notifier).state = updated.aiEnabled;
      ref.invalidate(sessionProvider);
      if (!mounted) return;
      setState(() {
        _editing = false;
        _aiEnabledDraft = null;
        _notice = '已同步到后端。';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _notice = '保存失败，请稍后再试。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleAiPolish(AuthSession session, bool enabled) async {
    if (_savingAiPolish) return;
    final previous = ref.read(aiPolishEnabledProvider);
    ref.read(aiPolishEnabledProvider.notifier).state = enabled;
    setState(() {
      _savingAiPolish = true;
      _notice = null;
      if (_editing) _aiEnabledDraft = enabled;
    });
    try {
      final updated = await ref.read(authRepositoryProvider).updateMe(
            nickname: session.nickname,
            avatarKey: session.avatarKey,
            aiEnabled: enabled,
            privacyMode: session.privacyMode,
          );
      ref.read(authSessionProvider.notifier).state = updated;
      ref.read(aiPolishEnabledProvider.notifier).state = updated.aiEnabled;
      ref.invalidate(sessionProvider);
      if (!mounted) return;
      setState(() {
        _savingAiPolish = false;
        _notice = updated.aiEnabled ? '已开启轻 AI 润色。' : '已关闭轻 AI 润色。';
      });
    } catch (_) {
      ref.read(aiPolishEnabledProvider.notifier).state = previous;
      if (!mounted) return;
      setState(() {
        _savingAiPolish = false;
        _notice = '轻润色偏好保存失败，请稍后再试。';
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('退出后需要重新登录才能查看光片。确定退出吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('退出')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authRepositoryProvider).logout();
    ref.read(authSessionProvider.notifier).state = null;
    ref.invalidate(sessionProvider);
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final sessionValue = ref.watch(sessionProvider);
    final nightMode = ref.watch(nightModeProvider);
    final islandsAsync = ref.watch(islandsProvider);
    final fragmentsAsync = ref.watch(fragmentsProvider);
    final api = ref.watch(apiClientProvider);

    return Stack(children: [
      const Positioned.fill(child: AtmosphereBackground()),
      SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 104),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: sessionValue.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => _ErrorPanel(),
                data: (session) {
                  _syncAiPolishProvider(session);
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header ──
                        Text('BOUNDARY',
                            style: AppText.onNight(AppText.eyebrow, nightMode)),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                              child: Text('我的',
                                  style: AppText.onNight(
                                      AppText.hero, nightMode))),
                          const NightModeButton(),
                        ]),
                        const SizedBox(height: 8),
                        Text('账号、隐私和那些你想自己决定的边界。',
                            style: AppText.onNight(AppText.body, nightMode)),
                        const SizedBox(height: 22),

                        // ── 资料 ──
                        _ProfileSummary(session: session, nightMode: nightMode),
                        const SizedBox(height: 14),
                        _SectionLabel('资料', nightMode: nightMode),
                        const SizedBox(height: 8),
                        _Card(nightMode: nightMode, children: [
                          if (!_editing) ...[
                            _InfoRow(
                                label: '昵称',
                                value: session.nickname,
                                nightMode: nightMode),
                            _InfoRow(
                                label: '用户名',
                                value: session.username,
                                nightMode: nightMode),
                            _InfoRow(
                                label: 'ID',
                                value: session.publicId.isEmpty
                                    ? '-'
                                    : session.publicId,
                                nightMode: nightMode),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => _enterEdit(session),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('编辑资料'),
                            ),
                          ] else ...[
                            TextField(
                                controller: _nickname,
                                decoration:
                                    const InputDecoration(labelText: '昵称')),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('星图管理员',
                                          style: AppText.onNight(
                                              AppText.body, nightMode)),
                                      const SizedBox(height: 4),
                                      Text('开启后，只在主动触发时提供建议。',
                                          style: AppText.onNight(
                                              AppText.caption, nightMode)),
                                    ]),
                              ),
                              Switch.adaptive(
                                value: _aiEnabledDraft ?? session.aiEnabled,
                                onChanged: _saving
                                    ? null
                                    : (v) =>
                                        setState(() => _aiEnabledDraft = v),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            if (_notice != null) ...[
                              Text(_notice!,
                                  style: AppText.onNight(
                                      AppText.caption, nightMode)),
                              const SizedBox(height: 10),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _saving
                                    ? null
                                    : () => _saveProfile(session),
                                icon: const Icon(Icons.cloud_done_outlined,
                                    size: 18),
                                label: Text(_saving ? '保存中...' : '保存资料'),
                              ),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 24),

                        // ── AI ──
                        _SectionLabel('AI', nightMode: nightMode),
                        const SizedBox(height: 8),
                        _Card(nightMode: nightMode, children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => context.push('/ai/build-islands'),
                            child: Row(children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.lilac.withValues(alpha: .22),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.auto_awesome_outlined,
                                    color: AppColors.ink, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('让 AI 帮我发现小岛',
                                          style: AppText.onNight(
                                              AppText.titleMedium, nightMode)),
                                      const SizedBox(height: 4),
                                      Text('读所有光片，发现隐秘联系，给出候选小岛。',
                                          style: AppText.onNight(
                                              AppText.caption, nightMode)),
                                    ]),
                              ),
                              Icon(Icons.chevron_right_rounded,
                                  color: nightMode
                                      ? AppText.nightInkMuted
                                      : AppColors.inkMuted),
                            ]),
                          ),
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('轻 AI 润色',
                                        style: AppText.onNight(
                                            AppText.titleMedium, nightMode)),
                                    const SizedBox(height: 4),
                                    Text('开启后，详情页和线页选中态出现润色按钮。',
                                        style: AppText.onNight(
                                            AppText.caption, nightMode)),
                                  ]),
                            ),
                            Consumer(
                              builder: (_, ref, __) => Switch.adaptive(
                                value: ref.watch(aiPolishEnabledProvider),
                                onChanged: _savingAiPolish
                                    ? null
                                    : (v) => _toggleAiPolish(session, v),
                              ),
                            ),
                          ]),
                        ]),
                        const SizedBox(height: 24),

                        // ── 同步 ──
                        _SectionLabel('同步', nightMode: nightMode),
                        const SizedBox(height: 8),
                        _Card(nightMode: nightMode, children: [
                          _InfoRow(
                              label: '服务',
                              value: api.baseUrl,
                              nightMode: nightMode),
                          _InfoRow(
                              label: 'Token',
                              value: api.hasToken ? '已认证' : '未登录',
                              nightMode: nightMode),
                          _InfoRow(
                              label: '策略',
                              value: '联网后自动推送变更。',
                              nightMode: nightMode),
                        ]),
                        const SizedBox(height: 24),

                        // ── 数据概览 ──
                        _SectionLabel('数据', nightMode: nightMode),
                        const SizedBox(height: 8),
                        fragmentsAsync.when(
                          data: (fragments) {
                            final islandCount =
                                islandsAsync.valueOrNull?.length ?? 0;
                            return _StatsCard(
                                fragmentCount: fragments.length,
                                islandCount: islandCount,
                                nightMode: nightMode);
                          },
                          loading: () => _StatsCard(
                              fragmentCount: 0,
                              islandCount: 0,
                              nightMode: nightMode),
                          error: (_, __) => _StatsCard(
                              fragmentCount: 0,
                              islandCount: 0,
                              nightMode: nightMode),
                        ),
                        const SizedBox(height: 24),

                        // ── 隐私 ──
                        _SectionLabel('隐私', nightMode: nightMode),
                        const SizedBox(height: 8),
                        _Card(nightMode: nightMode, children: [
                          _InfoRow(
                              label: '模式',
                              value: session.privacyMode == 'local'
                                  ? '本地优先'
                                  : '仅自己可见',
                              nightMode: nightMode),
                          const SizedBox(height: 10),
                          Text('所有内容默认仅自己可见。无公开主页、无点赞评论、无社交排名。',
                              style: AppText.onNight(
                                  AppText.bodyMuted, nightMode)),
                        ]),
                        const SizedBox(height: 24),

                        // ── 关于 ──
                        _SectionLabel('关于', nightMode: nightMode),
                        const SizedBox(height: 8),
                        _Card(nightMode: nightMode, children: [
                          Text('隙光 v0.2',
                              style: AppText.onNight(
                                  AppText.titleMedium, nightMode)),
                          const SizedBox(height: 8),
                          Text(
                              '私人多媒体碎片记录与回看工具。\n隙中捕光 → 光入成线 → 线间可织 → 织久成屿。\n\nAI 作为星图管理员辅助，不在后台分析，不替你解释。',
                              style: AppText.onNight(
                                  AppText.bodyMuted, nightMode)),
                        ]),
                        const SizedBox(height: 24),

                        // ── 退出 ──
                        _Card(nightMode: nightMode, children: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _logout,
                              icon: const Icon(Icons.logout_rounded, size: 16),
                              label: const Text('退出登录'),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.sunsetCoral),
                            ),
                          ),
                        ]),
                      ]);
                },
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  void _syncAiPolishProvider(AuthSession session) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _savingAiPolish) return;
      final current = ref.read(aiPolishEnabledProvider);
      if (current != session.aiEnabled) {
        ref.read(aiPolishEnabledProvider.notifier).state = session.aiEnabled;
      }
    });
  }
}

// ═══════════════════════════════════════════════════════════
// 共享组件
// ═══════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {required this.nightMode});
  final String label;
  final bool nightMode;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(label, style: AppText.onNight(AppText.eyebrow, nightMode)),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.nightMode, required this.children});
  final bool nightMode;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: nightMode ? _nightCard() : softDecoration(AppColors.white),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.label, required this.value, required this.nightMode});
  final String label, value;
  final bool nightMode;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 56,
              child: Text(label,
                  style: AppText.onNight(AppText.caption, nightMode))),
          Expanded(
              child:
                  Text(value, style: AppText.onNight(AppText.body, nightMode))),
        ]),
      );
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.session, required this.nightMode});
  final AuthSession session;
  final bool nightMode;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: nightMode ? _nightCard() : softDecoration(AppColors.white),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: AppColors.teaGreen.withValues(alpha: .22),
                borderRadius: BorderRadius.circular(8)),
            child:
                const Icon(Icons.person_outline_rounded, color: AppColors.ink),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(session.nickname,
                  style: AppText.onNight(AppText.titleMedium, nightMode)),
              const SizedBox(height: 3),
              Text('@${session.username}',
                  style: AppText.onNight(AppText.caption, nightMode)),
            ]),
          ),
        ]),
      );
}

class _StatsCard extends StatelessWidget {
  const _StatsCard(
      {required this.fragmentCount,
      required this.islandCount,
      required this.nightMode});
  final int fragmentCount, islandCount;
  final bool nightMode;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: nightMode ? _nightCard() : softDecoration(AppColors.white),
        child: Row(children: [
          _Stat(value: '$fragmentCount', label: '光片', nightMode: nightMode),
          Container(
              width: 1,
              height: 28,
              color: nightMode
                  ? AppColors.white.withValues(alpha: .10)
                  : AppColors.line),
          _Stat(value: '$islandCount', label: '小岛', nightMode: nightMode),
        ]),
      );
}

class _Stat extends StatelessWidget {
  const _Stat(
      {required this.value, required this.label, required this.nightMode});
  final String value, label;
  final bool nightMode;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: AppText.onNight(AppText.hero, nightMode)
                  .copyWith(fontSize: 28)),
          const SizedBox(height: 4),
          Text(label, style: AppText.onNight(AppText.caption, nightMode)),
        ]),
      );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: softDecoration(AppColors.white),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('账号状态暂时不可用', style: AppText.titleMedium),
          const SizedBox(height: 10),
          Text('可以重新登录，或检查后端连接。', style: AppText.body),
        ]),
      );
}

BoxDecoration _nightCard() => BoxDecoration(
      color: const Color(0xFF213433).withValues(alpha: .78),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.white.withValues(alpha: .13)),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: .16),
            blurRadius: 24,
            offset: const Offset(0, 14))
      ],
    );
