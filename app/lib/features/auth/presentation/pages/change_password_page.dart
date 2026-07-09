import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../ui/primitives/night_background.dart';
import '../../../../ui/primitives/page_back_button.dart';
import '../../../../ui/spaces/space_canvas.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _oldPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _oldPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final old = _oldPassword.text;
    final newPw = _newPassword.text;
    final confirm = _confirmPassword.text;

    if (old.isEmpty || newPw.isEmpty) {
      setState(() => _error = '请填写当前密码和新密码。');
      return;
    }
    if (newPw.length < 6) {
      setState(() => _error = '新密码至少需要 6 个字符。');
      return;
    }
    if (newPw != confirm) {
      setState(() => _error = '两次输入的新密码不一致。');
      return;
    }
    if (newPw == old) {
      setState(() => _error = '新密码不能和当前密码相同。');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).changePassword(
            oldPassword: old,
            newPassword: newPw,
          );
      if (!mounted) return;
      setState(() => _success = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '修改失败，请检查当前密码是否正确。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nightMode = ref.watch(nightModeProvider);
    return Stack(children: [
      const Positioned.fill(child: NightBackgroundPlaceholder()),
      const Positioned.fill(child: AtmosphereBackground()),
      Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(AppSpacing.s22,
                    AppSpacing.s12, AppSpacing.s22, AppSpacing.pageBottomNav),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(nightMode: nightMode),
                    const SizedBox(height: AppSpacing.lg),
                    if (_success) ...[
                      _SuccessCard(nightMode: nightMode),
                    ] else ...[
                      _Card(nightMode: nightMode, children: [
                        Text(
                          '修改密码',
                          style:
                              AppText.onNight(AppText.titleMedium, nightMode),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '修改后需要重新登录。',
                          style: AppText.onNight(AppText.bodyMuted, nightMode),
                        ),
                        const SizedBox(height: AppSpacing.s20),
                        TextField(
                          controller: _oldPassword,
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: '当前密码'),
                        ),
                        const SizedBox(height: AppSpacing.s14),
                        TextField(
                          controller: _newPassword,
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: '新密码'),
                        ),
                        const SizedBox(height: AppSpacing.s14),
                        TextField(
                          controller: _confirmPassword,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(labelText: '确认新密码'),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: AppSpacing.s14),
                          Text(
                            _error!,
                            style: AppText.onNight(AppText.caption, nightMode)
                                .copyWith(color: AppColors.sunsetCoral),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _submit,
                            icon: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.white,
                                    ),
                                  )
                                : const Icon(Icons.lock_outline_rounded,
                                    size: 18),
                            label: Text(_loading ? '修改中...' : '确认修改'),
                          ),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.nightMode});
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PageBackButton(
          onTap: () => Navigator.of(context).maybePop(),
          nightMode: nightMode,
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Text(
            '修改密码',
            style: AppText.onNight(
              AppText.titleLarge,
              nightMode,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.nightMode, required this.children});
  final bool nightMode;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.s18),
        decoration:
            nightMode ? nightDecoration() : softDecoration(AppColors.white),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.nightMode});
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return _Card(
      nightMode: nightMode,
      children: [
        Icon(Icons.check_circle_outline_rounded,
            size: 48,
            color: nightMode ? AppText.nightAccent : AppColors.teaGreen),
        const SizedBox(height: AppSpacing.md),
        Text('密码已修改', style: AppText.onNight(AppText.titleMedium, nightMode)),
        const SizedBox(height: AppSpacing.sm),
        Text('下次登录时请使用新密码。', style: AppText.onNight(AppText.body, nightMode)),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('返回'),
          ),
        ),
      ],
    );
  }
}
