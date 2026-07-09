import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../ui/composites/backend_url_tile.dart';
import '../../../../ui/primitives/glow_button.dart';
import '../../../../ui/primitives/night_background.dart';
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
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_loading) return;
    if (_username.text.trim().isEmpty ||
        _password.text.isEmpty ||
        _nickname.text.trim().isEmpty) {
      setState(() => _message = '请填写用户名、昵称和密码。');
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final session = await ref.read(authRepositoryProvider).register(
            username: _username.text.trim(),
            password: _password.text,
            nickname: _nickname.text.trim(),
          );
      ref.read(authSessionProvider.notifier).state = session;
      ref.invalidate(sessionProvider);
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
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nightMode = ref.watch(nightModeProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        const Positioned.fill(child: NightBackgroundPlaceholder()),
        const Positioned.fill(child: AtmosphereBackground(animated: false)),
        const Positioned.fill(child: _RegisterLightField()),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.s22, AppSpacing.s28,
                  AppSpacing.s22, AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s22,
                      AppSpacing.lg, AppSpacing.s22, AppSpacing.s22),
                  decoration: nightMode
                      ? nightDecoration()
                      : softDecoration(AppColors.white).copyWith(
                          color: AppColors.white.withValues(alpha: .86),
                          border: Border.all(
                            color: AppColors.white.withValues(alpha: .78),
                          ),
                        ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _RegisterMark(),
                      const SizedBox(height: AppSpacing.s14),
                      Text('创建账号',
                          style: AppText.onNight(AppText.hero, nightMode)),
                      const SizedBox(height: AppSpacing.s10),
                      Text('给这一束光一个安静入口，之后慢慢写。',
                          style: AppText.onNight(AppText.body, nightMode)),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        key: const ValueKey('register-username'),
                        controller: _username,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: '用户名'),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      TextField(
                        key: const ValueKey('register-nickname'),
                        controller: _nickname,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: '昵称'),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      TextField(
                        key: const ValueKey('register-password'),
                        controller: _password,
                        obscureText: true,
                        onSubmitted: (_) => _register(),
                        decoration: const InputDecoration(labelText: '密码'),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: AppSpacing.s12),
                        AuthNotice(message: _message!, nightMode: nightMode),
                      ],
                      const SizedBox(height: AppSpacing.s20),
                      GlowButton(
                        label: _loading ? '创建中...' : '创建并进入',
                        icon: Icons.auto_awesome_rounded,
                        onPressed: _loading ? null : _register,
                      ),
                      const SizedBox(height: AppSpacing.s10),
                      TextButton.icon(
                        onPressed:
                            _loading ? null : () => context.go('/login'),
                        icon: const Icon(Icons.login_rounded, size: 20),
                        label: const Text('已有账号，去登录'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      BackendUrlTile(loading: _loading, nightMode: nightMode),
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

class _RegisterMark extends ConsumerWidget {
  const _RegisterMark();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nightMode = ref.watch(nightModeProvider);
    return Row(children: [
      Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: nightMode
              ? AppColors.white.withValues(alpha: .12)
              : AppColors.white.withValues(alpha: .7),
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
