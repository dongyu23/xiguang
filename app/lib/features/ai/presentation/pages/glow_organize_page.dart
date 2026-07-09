// PAGE_SIZE_EXEMPT: migration in progress; prompt state and result sections will be extracted.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../ui/primitives/night_background.dart';
import '../../../../ui/primitives/page_back_button.dart';
import '../../../../ui/composites/xiguang_card.dart';
import '../../../../ui/composites/xiguang_chip.dart';
import '../../../../ui/composites/xiguang_input.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../../domain/ai_request.dart';
import '../../application/glow_organize_controller.dart';

class GlowOrganizePage extends ConsumerStatefulWidget {
  const GlowOrganizePage({super.key});

  @override
  ConsumerState<GlowOrganizePage> createState() => _GlowOrganizePageState();
}

class _GlowOrganizePageState extends ConsumerState<GlowOrganizePage> {
  final _inputController = TextEditingController();
  final _messageController = ScrollController();
  String _mode = 'weave';
  static const _quickPrompts = [
    _QuickPrompt(
      icon: Icons.account_tree_outlined,
      label: '看见靠近的线',
      prompt: '这些光片里，哪些主题正在靠近？',
    ),
    _QuickPrompt(
      icon: Icons.sell_outlined,
      label: '给这组光命名',
      prompt: '如果把最近的光片放在一起，可以怎么命名？',
    ),
    _QuickPrompt(
      icon: Icons.visibility_off_outlined,
      label: '只整理，不解释',
      prompt: '请只帮我整理线索，不做心理解释。',
    ),
  ];
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
    _messageController.dispose();
    super.dispose();
  }

  void _scrollMessagesToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messageController.hasClients) return;
      _messageController.animateTo(
        _messageController.position.maxScrollExtent,
        duration: AppMotion.fast,
        curve: AppMotion.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final loading = ref.watch(glowOrganizeControllerProvider).isLoading;
    final theme = NightTheme.of(context);
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.s22,
                    AppSpacing.s12, AppSpacing.s22, AppSpacing.s22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _GlowHeader(),
                    const SizedBox(height: AppSpacing.md),
                    const _GlowBriefing(),
                    const SizedBox(height: AppSpacing.s14),
                    _ModeSelector(
                      mode: _mode,
                      onChanged: (value) => setState(() => _mode = value),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    _QuickPromptRail(
                      prompts: _quickPrompts,
                      enabled: !loading,
                      onSelected: _requestGlowWithPrompt,
                    ),
                    const SizedBox(height: AppSpacing.s14),
                    Expanded(
                      child: XiguangCard(
                        padding: const EdgeInsets.all(AppSpacing.s14),
                        child: Column(children: [
                          Expanded(
                            child: ListView.separated(
                              controller: _messageController,
                              physics: const BouncingScrollPhysics(),
                              itemCount: _messages.length + (loading ? 1 : 0),
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.s10),
                              itemBuilder: (context, index) {
                                if (loading && index == _messages.length) {
                                  return const _TypingBubble();
                                }
                                return _MessageBubble(
                                  message: _messages[index],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          Row(children: [
                            Expanded(
                              child: XiguangInput(
                                controller: _inputController,
                                maxLines: 3,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _requestGlow(),
                                hint: '比如：哪些线已经织好了？',
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s10),
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: IconButton.filled(
                                tooltip: '发送',
                                style: IconButton.styleFrom(
                                  backgroundColor: theme.foreground,
                                  foregroundColor: theme.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                  ),
                                ),
                                onPressed: loading ? null : _requestGlow,
                                icon: const Icon(
                                  Icons.arrow_upward_rounded,
                                  semanticLabel: '发送',
                                ),
                              ),
                            ),
                          ]),
                        ]),
                      ),
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
    await _requestGlowWithPrompt(_inputController.text.trim());
  }

  Future<void> _requestGlowWithPrompt(String prompt) async {
    if (ref.read(glowOrganizeControllerProvider).isLoading) return;
    final contextText =
        prompt.isEmpty ? 'manual chat request from starmap' : prompt;
    setState(() {
      if (prompt.isNotEmpty) {
        _messages.add(_GlowMessage(fromUser: true, text: prompt));
        _inputController.clear();
      }
    });
    _scrollMessagesToEnd();
    try {
      final response = await ref
          .read(glowOrganizeControllerProvider.notifier)
          .request(AIRequest(mode: _mode, context: contextText));
      setState(() => _messages.add(
          _GlowMessage(fromUser: false, text: response.summary ?? '请求已送达。')));
      _scrollMessagesToEnd();
    } catch (_) {
      setState(() => _messages.add(const _GlowMessage(
          fromUser: false, text: '柔光整理暂时不可用，但不会影响捕光、织线和回看。')));
      _scrollMessagesToEnd();
    } finally {
      _scrollMessagesToEnd();
    }
  }
}

class _QuickPrompt {
  const _QuickPrompt({
    required this.icon,
    required this.label,
    required this.prompt,
  });

  final IconData icon;
  final String label;
  final String prompt;
}

class _GlowBriefing extends StatelessWidget {
  const _GlowBriefing();

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return XiguangCard(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s14, AppSpacing.s12, AppSpacing.s14, AppSpacing.s12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.accent.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            Icons.auto_awesome_outlined,
            size: 17,
            color: theme.accent,
          ),
        ),
        const SizedBox(width: AppSpacing.s10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STAR KEEPER',
                style: AppText.eyebrow.copyWith(color: theme.foregroundMuted),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '只在你主动发问时整理线索，不在后台解释你。',
                style: AppText.body.copyWith(color: theme.foreground),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _QuickPromptRail extends StatelessWidget {
  const _QuickPromptRail({
    required this.prompts,
    required this.enabled,
    required this.onSelected,
  });

  final List<_QuickPrompt> prompts;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final prompt in prompts)
          _QuickPromptChip(
            prompt: prompt,
            enabled: enabled,
            onTap: () => onSelected(prompt.prompt),
          ),
      ],
    );
  }
}

class _QuickPromptChip extends StatelessWidget {
  const _QuickPromptChip({
    required this.prompt,
    required this.enabled,
    required this.onTap,
  });

  final _QuickPrompt prompt;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return XiguangChip(
      label: prompt.label,
      selected: false,
      leading: Icon(prompt.icon, size: 15),
      onSelected: enabled ? (_) => onTap() : null,
    );
  }
}

class _GlowHeader extends StatelessWidget {
  const _GlowHeader();

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Row(
      children: [
        PageBackButton(
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Text(
            '柔光整理',
            style: AppText.titleLarge.copyWith(color: theme.foreground),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onChanged});

  final String mode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: 'weave',
          icon: Icon(Icons.account_tree_outlined, size: 16),
          label: Text('织线'),
        ),
        ButtonSegment(
          value: 'name',
          icon: Icon(Icons.sell_outlined, size: 16),
          label: Text('命名'),
        ),
        ButtonSegment(
          value: 'quiet',
          icon: Icon(Icons.visibility_off_outlined, size: 16),
          label: Text('不解释'),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (values) => onChanged(values.first),
    );
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
    final theme = NightTheme.of(context);
    return Align(
      alignment:
          message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s13, vertical: AppSpacing.s11),
        decoration: BoxDecoration(
          color: message.fromUser ? theme.foreground : theme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: message.fromUser ? null : Border.all(color: theme.border),
        ),
        child: Text(
          message.text,
          style: AppText.body.copyWith(
            color: message.fromUser ? theme.surface : theme.foreground,
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
    final theme = NightTheme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s13, vertical: AppSpacing.s11),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: theme.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '正在看这条线...',
            style: AppText.caption.copyWith(color: theme.foregroundMuted),
          ),
        ]),
      ),
    );
  }
}
