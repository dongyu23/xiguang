import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/primitives/glow_button.dart';
import '../../../../ui/spaces/space_canvas.dart';

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
      if (mounted) context.go('/capture');
    } catch (_) {
      setState(() => _message = '注册失败，请换一个用户名或检查后端连接。');
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
                      Text('NEW LIGHT', style: AppText.eyebrow),
                      const SizedBox(height: 8),
                      Text('创建账号', style: AppText.hero),
                      const SizedBox(height: 10),
                      Text('只需要一个安静的名字，先让闭环跑起来。', style: AppText.body),
                      const SizedBox(height: 24),
                      TextField(
                        key: const ValueKey('register-username'),
                        controller: _username,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: '用户名'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('register-nickname'),
                        controller: _nickname,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: '昵称'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('register-password'),
                        controller: _password,
                        obscureText: true,
                        onSubmitted: (_) => _register(),
                        decoration: const InputDecoration(labelText: '密码'),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 12),
                        Text(_message!, style: AppText.caption),
                      ],
                      const SizedBox(height: 20),
                      GlowButton(
                        label: _loading ? '创建中...' : '创建并进入',
                        icon: Icons.auto_awesome_rounded,
                        onPressed: _loading ? null : _register,
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: TextButton(
                          onPressed:
                              _loading ? null : () => context.go('/login'),
                          child: const Text('已有账号，去登录'),
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
