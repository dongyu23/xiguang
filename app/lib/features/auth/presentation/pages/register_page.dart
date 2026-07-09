import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';
import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../ui/composites/backend_url_tile.dart';
import '../../../../ui/composites/xiguang_button.dart';
import '../../../../ui/composites/xiguang_card.dart';
import '../../../../ui/composites/xiguang_input.dart';
import '../../../../ui/composites/xiguang_page.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../widgets/auth_notice.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _nickname = TextEditingController();
  String? _message;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (ref.read(authActionsControllerProvider).isLoading) return;
    if (_username.text.trim().isEmpty ||
        _password.text.isEmpty ||
        _nickname.text.trim().isEmpty) {
      setState(() => _message = '请填写用户名、昵称和密码。');
      return;
    }
    setState(() {
      _message = null;
    });
    try {
      await ref.read(authActionsControllerProvider.notifier).register(
            username: _username.text.trim(),
            password: _password.text,
            nickname: _nickname.text.trim(),
          );
      if (!mounted) return;
      final returnTo =
          GoRouterState.of(context).uri.queryParameters['return_to'];
      if (returnTo != null && returnTo.isNotEmpty) {
        context.go(Uri.decodeComponent(returnTo));
      } else {
        context.go('/capture');
      }
    } catch (_) {
      setState(() => _message = '注册失败，请换一个用户名或检查后端连接。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authActionsControllerProvider).isLoading;
    final theme = NightTheme.of(context);
    return XiguangPage(
      backgroundLayer: const Stack(children: [
        Positioned.fill(child: AtmosphereBackground(animated: false)),
        Positioned.fill(child: _RegisterLightField()),
      ]),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s22,
        AppSpacing.s28,
        AppSpacing.s22,
        AppSpacing.xl,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: XiguangCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _RegisterMark(),
              const SizedBox(height: AppSpacing.s14),
              Text('创建账号',
                  style: AppText.hero.copyWith(color: theme.foreground)),
              const SizedBox(height: AppSpacing.s10),
              Text(
                '给这一束光一个安静入口，之后慢慢写。',
                style: AppText.body.copyWith(color: theme.foregroundMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              XiguangInput(
                key: const ValueKey('register-username'),
                controller: _username,
                textInputAction: TextInputAction.next,
                label: '用户名',
              ),
              const SizedBox(height: AppSpacing.s12),
              XiguangInput(
                key: const ValueKey('register-nickname'),
                controller: _nickname,
                textInputAction: TextInputAction.next,
                label: '昵称',
              ),
              const SizedBox(height: AppSpacing.s12),
              XiguangInput(
                key: const ValueKey('register-password'),
                controller: _password,
                obscureText: true,
                onSubmitted: (_) => _register(),
                label: '密码',
              ),
              if (_message != null) ...[
                const SizedBox(height: AppSpacing.s12),
                AuthNotice(message: _message!),
              ],
              const SizedBox(height: AppSpacing.s20),
              XiguangButton(
                label: loading ? '创建中...' : '创建并进入',
                leading: const Icon(Icons.auto_awesome_rounded),
                loading: loading,
                onPressed: loading ? null : _register,
              ),
              const SizedBox(height: AppSpacing.s10),
              TextButton.icon(
                onPressed: loading ? null : () => context.go('/login'),
                icon: const Icon(Icons.login_rounded, size: 20),
                label: const Text('已有账号，去登录'),
              ),
              const SizedBox(height: AppSpacing.sm),
              BackendUrlTile(loading: loading),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisterMark extends StatelessWidget {
  const _RegisterMark();

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Row(children: [
      Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.surface.withValues(alpha: .7),
          border: Border.all(color: AppColors.teaGreen.withValues(alpha: .36)),
        ),
        child: Icon(
          Icons.auto_awesome_rounded,
          size: 18,
          color: AppColors.teaGreen.withValues(alpha: .95),
        ),
      ),
      const SizedBox(width: AppSpacing.s9),
      Text('NEW LIGHT', style: AppText.eyebrowLarge),
    ]);
  }
}

class _RegisterLightField extends StatelessWidget {
  const _RegisterLightField();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _RegisterLightPainter()),
    );
  }
}

class _RegisterLightPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wavePaint = Paint()
      ..color = AppColors.teaGreen.withValues(alpha: .075)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (var i = 0; i < 7; i++) {
      final y = size.height * (.2 + i * .11);
      final path = Path()..moveTo(-24, y);
      path.cubicTo(
        size.width * .28,
        y + 20,
        size.width * .6,
        y - 18,
        size.width + 28,
        y + 10,
      );
      canvas.drawPath(path, wavePaint);
    }

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.white.withValues(alpha: .46),
          AppColors.emotionHappy.withValues(alpha: .08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * .24, size.height * .22),
        radius: size.width * .5,
      ));
    canvas.drawCircle(
      Offset(size.width * .24, size.height * .22),
      size.width * .5,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
