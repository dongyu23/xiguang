import 'dart:async';
// PAGE_SIZE_EXEMPT: migration in progress; atmospheric painter and form card will be extracted.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';
import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../ui/composites/backend_url_tile.dart';
import '../../../../ui/composites/xiguang_button.dart';
import '../../../../ui/composites/xiguang_card.dart';
import '../../../../ui/composites/xiguang_input.dart';
import '../../../../ui/composites/xiguang_page.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../../domain/auth_session.dart';
import '../widgets/auth_notice.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  int _submitGeneration = 0;
  String? _message;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    await _submit(() {
      return ref.read(authActionsControllerProvider.notifier).login(
            username: _username.text.trim(),
            password: _password.text,
          );
    });
  }

  Future<void> _goRegister() async {
    _cancelPendingSubmit();
    await ref.read(authActionsControllerProvider.notifier).logout();
    if (mounted) context.go('/register');
  }

  void _cancelPendingSubmit() {
    _submitGeneration++;
    ref.read(authActionsControllerProvider.notifier).reset();
  }

  Future<void> _submit(Future<AuthSession> Function() action) async {
    if (ref.read(authActionsControllerProvider).isLoading) return;
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _message = '请输入用户名和密码。');
      return;
    }

    final generation = ++_submitGeneration;
    setState(() {
      _message = null;
    });

    try {
      await action().timeout(AppTiming.authRequestTimeout);
      if (!mounted || generation != _submitGeneration) return;
      final returnTo =
          GoRouterState.of(context).uri.queryParameters['return_to'];
      if (returnTo != null && returnTo.isNotEmpty) {
        context.go(Uri.decodeComponent(returnTo));
      } else {
        context.go('/capture');
      }
    } on TimeoutException {
      if (!mounted || generation != _submitGeneration) return;
      setState(() => _message = '后端连接超时，可以修改地址后再试。');
    } catch (_) {
      if (!mounted || generation != _submitGeneration) return;
      setState(() => _message = '登录失败，请检查账号、密码或后端连接。');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(authActionsControllerProvider).isLoading;
    final theme = NightTheme.of(context);
    return XiguangPage(
      backgroundLayer: const Stack(children: [
        Positioned.fill(child: AtmosphereBackground(animated: false)),
        Positioned.fill(child: _IntroLightField()),
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
              const _IntroMark(),
              const SizedBox(height: AppSpacing.s14),
              Text('隙光', style: AppText.hero.copyWith(color: theme.foreground)),
              const SizedBox(height: AppSpacing.s10),
              Text(
                '把今天轻轻放下，再慢慢看见它。',
                style: AppText.body.copyWith(color: theme.foregroundMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              XiguangInput(
                key: const ValueKey('login-username'),
                controller: _username,
                textInputAction: TextInputAction.next,
                label: '用户名',
              ),
              const SizedBox(height: AppSpacing.s12),
              XiguangInput(
                key: const ValueKey('login-password'),
                controller: _password,
                obscureText: true,
                onSubmitted: (_) => _login(),
                label: '密码',
              ),
              if (_message != null) ...[
                const SizedBox(height: AppSpacing.s12),
                AuthNotice(message: _message!),
              ],
              const SizedBox(height: AppSpacing.s20),
              XiguangButton(
                label: loading ? '进入中...' : '登录并捕光',
                leading: const Icon(Icons.login_rounded),
                loading: loading,
                onPressed: loading ? null : _login,
              ),
              const SizedBox(height: AppSpacing.s10),
              Center(
                child: TextButton.icon(
                  key: const ValueKey('go-register'),
                  onPressed: _goRegister,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('创建账号'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              BackendUrlTile(
                onBeginEdit: _cancelPendingSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroMark extends StatelessWidget {
  const _IntroMark();

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
        child: CustomPaint(
          painter: _TinyGlimmerPainter(),
          child: const SizedBox(width: AppSpacing.lg, height: AppSpacing.lg),
        ),
      ),
      const SizedBox(width: AppSpacing.s9),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Glimmer', style: AppText.eyebrowLarge),
      ]),
    ]);
  }
}

class _IntroLightField extends StatelessWidget {
  const _IntroLightField();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _IntroLightPainter()),
    );
  }
}

class _IntroLightPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final wavePaint = Paint()
      ..color = AppColors.teaGreen.withValues(alpha: .09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 8; i++) {
      final y = size.height * (.18 + i * .1);
      final path = Path()..moveTo(-20, y);
      path.cubicTo(
        size.width * .25,
        y - 22,
        size.width * .55,
        y + 18,
        size.width + 24,
        y - 8,
      );
      canvas.drawPath(path, wavePaint);
    }

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.white.withValues(alpha: .5),
          AppColors.teaGreen.withValues(alpha: .08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * .78, size.height * .22),
        radius: size.width * .52,
      ));
    canvas.drawCircle(
      Offset(size.width * .78, size.height * .22),
      size.width * .52,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TinyGlimmerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.teaGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 8; i++) {
      final angle = i * .785;
      final inner = Offset(
        center.dx + cos(angle) * 4,
        center.dy + sin(angle) * 4,
      );
      final outer = Offset(
        center.dx + cos(angle) * 9,
        center.dy + sin(angle) * 9,
      );
      canvas.drawLine(inner, outer, paint);
    }
    canvas.drawCircle(center, 2.3, Paint()..color = AppColors.teaGreen);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
