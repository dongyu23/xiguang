import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../ui/primitives/glow_button.dart';
import '../../../../ui/spaces/space_canvas.dart';

class MinePage extends ConsumerStatefulWidget {
  const MinePage({super.key});

  @override
  ConsumerState<MinePage> createState() => _MinePageState();
}

class _MinePageState extends ConsumerState<MinePage> {
  final _nickname = TextEditingController();
  final _avatarKey = TextEditingController();
  bool _aiEnabled = false;
  String _privacyMode = 'private';
  bool _editing = false;
  bool _saving = false;
  String? _notice;
  String? _loadedFingerprint;
  AuthSession? _displaySession;

  @override
  void dispose() {
    _nickname.dispose();
    _avatarKey.dispose();
    super.dispose();
  }

  void _load(AuthSession session) {
    final fingerprint = [
      session.id,
      session.publicId,
      session.nickname,
      session.avatarKey,
      session.aiEnabled,
      session.privacyMode,
    ].join('|');
    if (_loadedFingerprint == fingerprint) return;
    if (_editing && _loadedFingerprint != null) return;
    _loadedFingerprint = fingerprint;
    _nickname.text = session.nickname;
    _avatarKey.text = session.avatarKey;
    _aiEnabled = session.aiEnabled;
    _privacyMode = session.privacyMode;
  }

  AuthSession _visibleSession(AuthSession session) {
    final display = _displaySession;
    if (display == null) return session;
    if (display.id == session.id && display.publicId == session.publicId) {
      return display;
    }
    _displaySession = null;
    return session;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _notice = null;
    });
    try {
      final updated = await ref.read(authRepositoryProvider).updateMe(
            nickname: _nickname.text,
            avatarKey: _avatarKey.text,
            aiEnabled: _aiEnabled,
            privacyMode: _privacyMode,
          );
      ref.read(authSessionProvider.notifier).state = updated;
      setState(() {
        _displaySession = updated;
        _editing = false;
        _notice = '已同步到后端。';
      });
    } catch (_) {
      setState(() => _notice = '保存失败，请稍后再试。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _logout() {
    ref.read(authRepositoryProvider).logout();
    ref.read(authSessionProvider.notifier).state = null;
    ref.invalidate(sessionProvider);
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final sessionValue = ref.watch(sessionProvider);
    final api = ref.watch(apiClientProvider);
    return Stack(children: [
      const Positioned.fill(child: AtmosphereBackground()),
      SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 104),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: sessionValue.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: 120),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => _ErrorPanel(onLogout: _logout),
                data: (session) {
                  final visibleSession = _visibleSession(session);
                  _load(visibleSession);
                  final cardSession = (_editing || _notice != null)
                      ? visibleSession.copyWith(
                          nickname: _nickname.text.trim().isEmpty
                              ? visibleSession.nickname
                              : _nickname.text.trim(),
                          avatarKey: _avatarKey.text.trim(),
                          aiEnabled: _aiEnabled,
                          privacyMode: _privacyMode,
                        )
                      : visibleSession;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BOUNDARY', style: AppText.eyebrow),
                      const SizedBox(height: 8),
                      Text('我的', style: AppText.hero),
                      const SizedBox(height: 8),
                      Text('账号、同步、隐私和那些你想自己决定的边界。', style: AppText.body),
                      const SizedBox(height: 22),
                      _ProfileCard(
                        session: cardSession,
                        editing: _editing,
                        nickname: _nickname,
                        avatarKey: _avatarKey,
                        aiEnabled: _aiEnabled,
                        privacyMode: _privacyMode,
                        onEditChanged: (value) => setState(() {
                          _editing = value;
                          _notice = null;
                          if (!value) _load(visibleSession);
                        }),
                        onAIChanged: (value) =>
                            setState(() => _aiEnabled = value),
                        onPrivacyChanged: (value) =>
                            setState(() => _privacyMode = value),
                        onSave: _save,
                        saving: _saving,
                      ),
                      if (_notice != null) ...[
                        const SizedBox(height: 10),
                        Text(_notice!, style: AppText.caption),
                      ],
                      const SizedBox(height: 14),
                      _SyncCard(apiBaseUrl: api.baseUrl, session: cardSession),
                      const SizedBox(height: 14),
                      _BoundaryCard(onLogout: _logout),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        key: const ValueKey('settings-link'),
                        onPressed: () => context.go('/settings'),
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('打开设置'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.session,
    required this.editing,
    required this.nickname,
    required this.avatarKey,
    required this.aiEnabled,
    required this.privacyMode,
    required this.onEditChanged,
    required this.onAIChanged,
    required this.onPrivacyChanged,
    required this.onSave,
    required this.saving,
  });

  final AuthSession session;
  final bool editing;
  final TextEditingController nickname;
  final TextEditingController avatarKey;
  final bool aiEnabled;
  final String privacyMode;
  final ValueChanged<bool> onEditChanged;
  final ValueChanged<bool> onAIChanged;
  final ValueChanged<String> onPrivacyChanged;
  final VoidCallback onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: softDecoration(AppColors.white),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.teaGreen.withValues(alpha: .26),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.person_outline_rounded, color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(session.nickname, style: AppText.titleMedium),
              const SizedBox(height: 4),
              Text(
                '云端同步已连接',
                style: AppText.caption,
              ),
            ]),
          ),
          IconButton(
            key: const ValueKey('profile-edit-toggle'),
            tooltip: editing ? '取消编辑' : '编辑资料',
            onPressed: () => onEditChanged(!editing),
            icon: Icon(editing ? Icons.close_rounded : Icons.edit_outlined),
          ),
        ]),
        const SizedBox(height: 16),
        _InfoRow(label: '用户名', value: session.username),
        _InfoRow(
            label: '用户ID',
            value: session.publicId.isEmpty ? '-' : session.publicId),
        if (!editing) ...[
          _InfoRow(
              label: '头像',
              value: session.avatarKey.isEmpty ? '未设置' : session.avatarKey),
          _InfoRow(label: '隐私', value: _privacyLabel(session.privacyMode)),
          _InfoRow(
              label: 'AI', value: session.aiEnabled ? '允许主动触发星图管理员' : '关闭'),
        ] else ...[
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('profile-nickname'),
            controller: nickname,
            decoration: const InputDecoration(labelText: '昵称'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('profile-avatar-key'),
            controller: avatarKey,
            decoration: const InputDecoration(labelText: '头像对象 Key'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('profile-privacy-mode'),
            initialValue: privacyMode,
            decoration: const InputDecoration(labelText: '隐私模式'),
            items: const [
              DropdownMenuItem(value: 'private', child: Text('仅自己可见')),
              DropdownMenuItem(value: 'local', child: Text('本地优先')),
            ],
            onChanged: (value) {
              if (value != null) onPrivacyChanged(value);
            },
          ),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('启用星图管理员', style: AppText.body),
                  const SizedBox(height: 2),
                  Text('只在你主动触发时给候选建议。', style: AppText.caption),
                ],
              ),
            ),
            Switch.adaptive(
              key: const ValueKey('profile-ai-enabled'),
              value: aiEnabled,
              onChanged: onAIChanged,
            ),
          ]),
          const SizedBox(height: 12),
          GlowButton(
            key: const ValueKey('profile-save'),
            label: saving ? '保存中...' : '保存到账号',
            icon: Icons.cloud_done_outlined,
            onPressed: saving ? null : onSave,
          ),
        ],
      ]),
    );
  }

  static String _privacyLabel(String value) {
    return switch (value) {
      'local' => '本地优先',
      _ => '仅自己可见',
    };
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({required this.apiBaseUrl, required this.session});

  final String apiBaseUrl;
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: softDecoration(AppColors.white),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('同步状态', style: AppText.titleMedium),
        const SizedBox(height: 10),
        _InfoRow(label: 'API', value: apiBaseUrl),
        _InfoRow(label: '状态', value: '后端账号'),
        _InfoRow(label: '策略', value: '捕光先可用，联网后通过同步接口推送。'),
      ]),
    );
  }
}

class _BoundaryCard extends StatelessWidget {
  const _BoundaryCard({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: softDecoration(AppColors.white),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('数据边界', style: AppText.titleMedium),
        const SizedBox(height: 10),
        Text(
          '当前版本不提供公开发布、点赞、评论或排名。柔光整理只会在你主动触发时出现。',
          style: AppText.body,
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          key: const ValueKey('logout-button'),
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('退出登录'),
        ),
      ]),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: softDecoration(AppColors.white),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('账号状态暂时不可用', style: AppText.titleMedium),
        const SizedBox(height: 10),
        Text('可以重新登录，或检查后端连接。', style: AppText.body),
        const SizedBox(height: 14),
        OutlinedButton(onPressed: onLogout, child: const Text('回到登录')),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

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
