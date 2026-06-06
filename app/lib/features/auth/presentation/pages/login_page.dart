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
      body: Stack(children: [
        const Positioned.fill(child: AtmosphereBackground()),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: softDecoration(AppColors.white),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('XIGUANG', style: AppText.eyebrow),
                      const SizedBox(height: 8),
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
                          onPressed:
                              _loading ? null : () => context.go('/register'),
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: const Text('注册新账号'),
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
