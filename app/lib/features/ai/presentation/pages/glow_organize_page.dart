import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/primitives/glow_button.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../../domain/ai_request.dart';

class GlowOrganizePage extends ConsumerStatefulWidget {
  const GlowOrganizePage({super.key});

  @override
  ConsumerState<GlowOrganizePage> createState() => _GlowOrganizePageState();
}

class _GlowOrganizePageState extends ConsumerState<GlowOrganizePage> {
  final _inputController = TextEditingController();
  String _mode = 'weave';
  bool _loading = false;
  final List<_GlowMessage> _messages = [
    _GlowMessage(
      fromUser: false,
      text: '我在。可以把你想问的线丢过来，比如“这些主题为什么会靠近？”',
    ),
    _GlowMessage(
      fromUser: false,
      text: '我只会在你主动发问时回应，不会在后台解释你。',
    ),
  ];

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(child: AtmosphereBackground()),
      Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('柔光整理'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 104),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STAR KEEPER', style: AppText.eyebrow),
                    const SizedBox(height: 8),
                    Text('AI 星图对话', style: AppText.hero.copyWith(fontSize: 28)),
                    const SizedBox(height: 8),
                    Text('像聊天一样，把已织好的线拿来问一问。', style: AppText.body),
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                            value: 'weave',
                            icon: Icon(Icons.account_tree_outlined, size: 16),
                            label: Text('织线')),
                        ButtonSegment(
                            value: 'name',
                            icon: Icon(Icons.sell_outlined, size: 16),
                            label: Text('命名')),
                        ButtonSegment(
                            value: 'quiet',
                            icon: Icon(Icons.visibility_off_outlined, size: 16),
                            label: Text('不解释')),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (values) =>
                          setState(() => _mode = values.first),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 420,
                      padding: const EdgeInsets.all(14),
                      decoration: softDecoration(AppColors.white),
                      child: Column(children: [
                        Expanded(
                          child: ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _messages.length + (_loading ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              if (_loading && index == _messages.length) {
                                return const _TypingBubble();
                              }
                              return _MessageBubble(message: _messages[index]);
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _inputController,
                              minLines: 1,
                              maxLines: 3,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _requestGlow(),
                              decoration: InputDecoration(
                                hintText: '比如：哪些线已经织好了？',
                                hintStyle: AppText.placeholder,
                                filled: true,
                                fillColor: AppColors.paper,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      const BorderSide(color: AppColors.line),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      const BorderSide(color: AppColors.line),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: AppColors.teaGreen),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 48,
                            height: 48,
                            child: IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.ink,
                                foregroundColor: AppColors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _loading ? null : _requestGlow,
                              icon: const Icon(Icons.arrow_upward_rounded),
                            ),
                          ),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    GlowButton(
                      label: _loading ? '正在轻轻整理' : '直接请求柔光整理',
                      icon: Icons.auto_awesome_outlined,
                      onPressed: _loading ? null : _requestGlow,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Future<void> _requestGlow() async {
    final prompt = _inputController.text.trim();
    final contextText =
        prompt.isEmpty ? 'manual chat request from starmap' : prompt;
    setState(() {
      _loading = true;
      if (prompt.isNotEmpty) {
        _messages.add(_GlowMessage(fromUser: true, text: prompt));
        _inputController.clear();
      }
    });
    try {
      final response = await ref.read(aiRepositoryProvider).glowSummary(
            AIRequest(mode: _mode, context: contextText),
          );
      setState(() => _messages.add(
          _GlowMessage(fromUser: false, text: response.summary ?? '请求已送达。')));
    } catch (_) {
      setState(() => _messages.add(const _GlowMessage(
          fromUser: false, text: '柔光整理暂时不可用，但不会影响捕光、织线和回看。')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _GlowMessage {
  const _GlowMessage({required this.fromUser, required this.text});

  final bool fromUser;
  final String text;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _GlowMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: message.fromUser ? AppColors.ink : AppColors.paper,
          borderRadius: BorderRadius.circular(8),
          border: message.fromUser
              ? null
              : Border.all(color: AppColors.line.withValues(alpha: .86)),
        ),
        child: Text(
          message.text,
          style: AppText.body.copyWith(
            color: message.fromUser ? AppColors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line.withValues(alpha: .86)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text('正在看这条线...', style: AppText.caption),
        ]),
      ),
    );
  }
}
