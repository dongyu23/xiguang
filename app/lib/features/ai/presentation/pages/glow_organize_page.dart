import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../ui/primitives/night_background.dart';
import '../../../../ui/primitives/page_back_button.dart';
import '../../../../ui/spaces/space_canvas.dart';
import '../../domain/ai_request.dart';

class GlowOrganizePage extends ConsumerStatefulWidget {
  const GlowOrganizePage({super.key});

  @override
  ConsumerState<GlowOrganizePage> createState() => _GlowOrganizePageState();
}

class _GlowOrganizePageState extends ConsumerState<GlowOrganizePage> {
  final _inputController = TextEditingController();
  final _messageController = ScrollController();
  String _mode = 'weave';
  bool _loading = false;
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.s22,
                    AppSpacing.s12, AppSpacing.s22, AppSpacing.s22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GlowHeader(nightMode: nightMode),
                    const SizedBox(height: AppSpacing.md),
                    _GlowBriefing(nightMode: nightMode),
                    const SizedBox(height: AppSpacing.s14),
                    _ModeSelector(
                      mode: _mode,
                      onChanged: (value) => setState(() => _mode = value),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    _QuickPromptRail(
                      prompts: _quickPrompts,
                      nightMode: nightMode,
                      enabled: !_loading,
                      onSelected: _requestGlowWithPrompt,
                    ),
                    const SizedBox(height: AppSpacing.s14),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.s14),
                        decoration: softDecoration(
                          nightMode
                              ? AppColors.ink.withValues(alpha: .72)
                              : AppColors.white,
                          nightMode: nightMode,
                        ),
                        child: Column(children: [
                          Expanded(
                            child: ListView.separated(
                              controller: _messageController,
                              physics: const BouncingScrollPhysics(),
                              itemCount: _messages.length + (_loading ? 1 : 0),
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.s10),
                              itemBuilder: (context, index) {
                                if (_loading && index == _messages.length) {
                                  return _TypingBubble(nightMode: nightMode);
                                }
                                return _MessageBubble(
                                  message: _messages[index],
                                  nightMode: nightMode,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          Row(children: [
                            Expanded(
                              child: TextField(
                                controller: _inputController,
                                minLines: 1,
                                maxLines: 3,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _requestGlow(),
                                style: AppText.onNight(AppText.body, nightMode),
                                decoration: InputDecoration(
                                  hintText: '比如：哪些线已经织好了？',
                                  hintStyle: AppText.onNight(
                                      AppText.placeholder, nightMode),
                                  filled: true,
                                  fillColor: nightMode
                                      ? AppColors.white.withValues(alpha: .08)
                                      : AppColors.paper,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.s12,
                                      vertical: AppSpacing.s12),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                    borderSide: BorderSide(
                                      color: nightMode
                                          ? AppColors.white
                                              .withValues(alpha: .12)
                                          : AppColors.line,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                    borderSide: BorderSide(
                                      color: nightMode
                                          ? AppColors.white
                                              .withValues(alpha: .12)
                                          : AppColors.line,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                    borderSide: const BorderSide(
                                        color: AppColors.teaGreen),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s10),
                            SizedBox(
                              width: 48,
                              height: 48,
                              child: IconButton.filled(
                                tooltip: '发送',
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.ink,
                                  foregroundColor: AppColors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                  ),
                                ),
                                onPressed: _loading ? null : _requestGlow,
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
    if (_loading) return;
    final contextText =
        prompt.isEmpty ? 'manual chat request from starmap' : prompt;
    setState(() {
      _loading = true;
      if (prompt.isNotEmpty) {
        _messages.add(_GlowMessage(fromUser: true, text: prompt));
        _inputController.clear();
      }
    });
    _scrollMessagesToEnd();
    try {
      final response = await ref.read(aiRepositoryProvider).glowSummary(
            AIRequest(mode: _mode, context: contextText),
          );
      setState(() => _messages.add(
          _GlowMessage(fromUser: false, text: response.summary ?? '请求已送达。')));
      _scrollMessagesToEnd();
    } catch (_) {
      setState(() => _messages.add(const _GlowMessage(
          fromUser: false, text: '柔光整理暂时不可用，但不会影响捕光、织线和回看。')));
      _scrollMessagesToEnd();
    } finally {
      if (mounted) setState(() => _loading = false);
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
  const _GlowBriefing({required this.nightMode});

  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    final color =
        nightMode ? AppColors.white.withValues(alpha: .08) : AppColors.white;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s14, AppSpacing.s12, AppSpacing.s14, AppSpacing.s12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: nightMode
              ? AppColors.white.withValues(alpha: .12)
              : AppColors.line.withValues(alpha: .72),
        ),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.teaGreen.withValues(alpha: nightMode ? .22 : .14),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            Icons.auto_awesome_outlined,
            size: 17,
            color: nightMode ? AppColors.emotionHappy : AppColors.teaGreen,
          ),
        ),
        const SizedBox(width: AppSpacing.s10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STAR KEEPER',
                style: AppText.onNight(AppText.eyebrow, nightMode),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '只在你主动发问时整理线索，不在后台解释你。',
                style: AppText.onNight(AppText.body, nightMode),
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
    required this.nightMode,
    required this.enabled,
    required this.onSelected,
  });

  final List<_QuickPrompt> prompts;
  final bool nightMode;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final prompt in prompts)
          _QuickPromptChip(
            prompt: prompt,
            nightMode: nightMode,
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
    required this.nightMode,
    required this.enabled,
    required this.onTap,
  });

  final _QuickPrompt prompt;
  final bool nightMode;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 统一为 Material ActionChip — §10 钦定的标准 chip 组件。
    final fg = nightMode ? AppText.nightInk : AppColors.ink;
    return ActionChip(
      onPressed: enabled ? onTap : null,
      avatar: Icon(prompt.icon, size: 15, color: fg),
      label: Text(prompt.label),
      labelStyle: AppText.onNight(AppText.captionStrong, nightMode),
      backgroundColor: nightMode
          ? AppColors.white.withValues(alpha: enabled ? .08 : .04)
          : AppColors.paper.withValues(alpha: enabled ? 1 : .56),
      side: BorderSide(
        color: nightMode
            ? AppColors.white.withValues(alpha: .10)
            : AppColors.line.withValues(alpha: .82),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    );
  }
}

class _GlowHeader extends StatelessWidget {
  const _GlowHeader({required this.nightMode});

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
            '柔光整理',
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
  const _MessageBubble({required this.message, required this.nightMode});

  final _GlowMessage message;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    final assistantBackground =
        nightMode ? AppColors.white.withValues(alpha: .08) : AppColors.paper;
    final assistantText = nightMode ? AppText.nightInk : AppColors.ink;
    return Align(
      alignment:
          message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s13, vertical: AppSpacing.s11),
        decoration: BoxDecoration(
          color: message.fromUser
              ? (nightMode ? AppColors.nightButton : AppColors.ink)
              : assistantBackground,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: message.fromUser
              ? null
              : Border.all(
                  color: nightMode
                      ? AppColors.white.withValues(alpha: .12)
                      : AppColors.line.withValues(alpha: .86)),
        ),
        child: Text(
          message.text,
          style: AppText.onNight(AppText.body, nightMode).copyWith(
            color: message.fromUser
                ? (nightMode ? AppColors.emotionHappy : AppColors.white)
                : assistantText,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({required this.nightMode});

  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s13, vertical: AppSpacing.s11),
        decoration: BoxDecoration(
          color: nightMode
              ? AppColors.white.withValues(alpha: .08)
              : AppColors.paper,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: nightMode
                ? AppColors.white.withValues(alpha: .12)
                : AppColors.line.withValues(alpha: .86),
          ),
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
            style: AppText.onNight(AppText.caption, nightMode),
          ),
        ]),
      ),
    );
  }
}
