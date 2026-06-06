import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/primitives/glow_button.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../../data/auth_repository.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    await _submit(() {
      return ref.read(authRepositoryProvider).login(
            username: _username.text.trim(),
            password: _password.text,
          );
    });
  }

  Future<void> _goRegister() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await ref.read(authRepositoryProvider).logout();
      ref.read(authSessionProvider.notifier).state = null;
      ref.invalidate(sessionProvider);
      if (mounted) context.go('/register');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit(Future<AuthSession> Function() action) async {
    if (_loading) return;
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _message = '请输入用户名和密码。');
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final session = await action();
      ref.read(authSessionProvider.notifier).state = session;
      ref.invalidate(sessionProvider);
      if (mounted) context.go('/capture');
    } catch (_) {
      setState(() => _message = '登录失败，请检查账号、密码或后端连接。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        const Positioned.fill(child: AtmosphereBackground()),
        const Positioned.fill(child: _IntroLightField()),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                  decoration: softDecoration(AppColors.white).copyWith(
                    color: AppColors.white.withValues(alpha: .86),
                    border: Border.all(
                      color: AppColors.white.withValues(alpha: .78),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _IntroMark(),
                      const SizedBox(height: 14),
                      Text('隙光', style: AppText.hero),
                      const SizedBox(height: 10),
                      Text('把今天轻轻放下，再慢慢看见它。', style: AppText.body),
                      const SizedBox(height: 24),
                      TextField(
                        key: const ValueKey('login-username'),
                        controller: _username,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: '用户名'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('login-password'),
                        controller: _password,
                        obscureText: true,
                        onSubmitted: (_) => _login(),
                        decoration: const InputDecoration(labelText: '密码'),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 12),
                        Text(_message!, style: AppText.caption),
                      ],
                      const SizedBox(height: 20),
                      GlowButton(
                        label: _loading ? '进入中...' : '登录并捕光',
                        icon: Icons.login_rounded,
                        onPressed: _loading ? null : _login,
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: TextButton.icon(
                          key: const ValueKey('go-register'),
                          onPressed: _loading ? null : _goRegister,
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('创建账号'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _IntroMark extends StatelessWidget {
  const _IntroMark();

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.white.withValues(alpha: .7),
          border: Border.all(color: AppColors.teaGreen.withValues(alpha: .36)),
        ),
        child: CustomPaint(
          painter: _TinyGlimmerPainter(),
          child: const SizedBox(width: 24, height: 24),
        ),
      ),
      const SizedBox(width: 9),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Glimmer', style: AppText.eyebrow.copyWith(fontSize: 13)),
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
