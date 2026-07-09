import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';
import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../ui/composites/xiguang_button.dart';
import '../../../../ui/composites/xiguang_card.dart';
import '../../../../ui/composites/xiguang_input.dart';
import '../../../../ui/composites/xiguang_page.dart';
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

    setState(() => _error = null);
    try {
      await ref.read(authActionsControllerProvider.notifier).changePassword(
            oldPassword: old,
            newPassword: newPw,
          );
      if (!mounted) return;
      setState(() => _success = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '修改失败，请检查当前密码是否正确。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(authActionsControllerProvider);
    final theme = NightTheme.of(context);
    return XiguangPage(
      backgroundLayer: const AtmosphereBackground(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s22,
        AppSpacing.s12,
        AppSpacing.s22,
        AppSpacing.pageBottomNav,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(),
          const SizedBox(height: AppSpacing.lg),
          if (_success)
            const _SuccessCard()
          else
            XiguangCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '修改密码',
                    style: AppText.titleSmall.copyWith(color: theme.foreground),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '修改后需要重新登录。',
                    style: AppText.bodyMuted
                        .copyWith(color: theme.foregroundMuted),
                  ),
                  const SizedBox(height: AppSpacing.s20),
                  XiguangInput(
                    controller: _oldPassword,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    label: '当前密码',
                  ),
                  const SizedBox(height: AppSpacing.s14),
                  XiguangInput(
                    controller: _newPassword,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    label: '新密码',
                  ),
                  const SizedBox(height: AppSpacing.s14),
                  XiguangInput(
                    controller: _confirmPassword,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    label: '确认新密码',
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.s14),
                    Text(
                      _error!,
                      style: AppText.caption.copyWith(color: theme.danger),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  XiguangButton(
                    label: actionState.isLoading ? '修改中...' : '确认修改',
                    loading: actionState.isLoading,
                    leading: const Icon(Icons.lock_outline_rounded, size: 18),
                    onPressed: actionState.isLoading ? null : _submit,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(Icons.arrow_back_rounded, color: theme.foreground),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Text(
            '修改密码',
            style: AppText.titleLarge.copyWith(color: theme.foreground),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard();

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return XiguangCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.check_circle_outline_rounded, size: 48, color: theme.accent),
        const SizedBox(height: AppSpacing.md),
        Text('密码已修改',
            style: AppText.titleSmall.copyWith(color: theme.foreground)),
        const SizedBox(height: AppSpacing.sm),
        Text('下次登录时请使用新密码。',
            style: AppText.body.copyWith(color: theme.foregroundMuted)),
        const SizedBox(height: AppSpacing.lg),
        XiguangButton(
          label: '返回',
          variant: XiguangButtonVariant.secondary,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ]),
    );
  }
}
