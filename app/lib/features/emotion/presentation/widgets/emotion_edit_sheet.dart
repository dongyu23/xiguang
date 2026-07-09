import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/composites/xiguang_bottom_sheet.dart';
import '../../../../ui/composites/xiguang_button.dart';
import '../../../../ui/composites/xiguang_input.dart';
import '../../application/audio_library_controller.dart';
import '../../application/emotions_controller.dart';
import '../../domain/user_emotion.dart';

class EmotionEditSheet extends ConsumerStatefulWidget {
  const EmotionEditSheet({super.key, required this.existing});

  final UserEmotion? existing;

  @override
  ConsumerState<EmotionEditSheet> createState() => _EmotionEditSheetState();
}

class _EmotionEditSheetState extends ConsumerState<EmotionEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late Color _color;
  String? _soundKey;

  @override
  void initState() {
    super.initState();
    final emotion = widget.existing;
    _nameController = TextEditingController(text: emotion?.name ?? '');
    _descriptionController =
        TextEditingController(text: emotion?.description ?? '');
    _color = emotion?.color ?? autoColorForEmotionName('');
    _soundKey = emotion?.soundKey;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final saving = ref.watch(emotionsProvider).isLoading;
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final maxSheetHeight = mediaQuery.size.height -
        bottomInset -
        mediaQuery.padding.top -
        AppSpacing.md;
    final isEdit = widget.existing != null;
    return AnimatedPadding(
      duration: AppMotion.fast,
      curve: AppMotion.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: XiguangBottomSheet(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _dismissKeyboard,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(isEdit ? '编辑心情' : '新增心情',
                        style: AppText.titleLarge
                            .copyWith(color: theme.foreground)),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    icon:
                        Icon(Icons.close_rounded, color: theme.foregroundMuted),
                    onPressed: _close,
                  ),
                ]),
                const SizedBox(height: AppSpacing.md),
                Flexible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: _buildForm(theme, isEdit),
                  ),
                ),
                const SizedBox(height: AppSpacing.s14),
                Divider(height: 1, color: theme.border),
                const SizedBox(height: AppSpacing.s14),
                XiguangButton(
                  label: saving ? '保存中…' : '保存',
                  loading: saving,
                  leading: const Icon(Icons.check_rounded, size: 18),
                  onPressed: saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(NightTheme theme, bool isEdit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        XiguangInput(
          controller: _nameController,
          maxLength: 8,
          autofocus: !isEdit,
          textInputAction: TextInputAction.next,
          label: '心情名字',
          hint: '例如：释怀',
        ),
        const SizedBox(height: AppSpacing.s6),
        XiguangInput(
          controller: _descriptionController,
          maxLength: 30,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _dismissKeyboard(),
          label: '一句话描述（可选）',
          hint: '这种感觉是…',
        ),
        const SizedBox(height: AppSpacing.md),
        Text('颜色',
            style: AppText.caption.copyWith(color: theme.foregroundMuted)),
        const SizedBox(height: AppSpacing.s6),
        Wrap(
          spacing: AppSpacing.s6,
          runSpacing: AppSpacing.s6,
          children: AppColors.emotionEditorPalette.map((color) {
            final selected = _color == color;
            return GestureDetector(
              onTap: () {
                _dismissKeyboard();
                setState(() => _color = color);
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? theme.foreground : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('声音',
            style: AppText.caption.copyWith(color: theme.foregroundMuted)),
        const SizedBox(height: AppSpacing.s6),
        _buildSoundChips(theme),
      ],
    );
  }

  /// 音频选择 - 合并内置音频与用户自定义音频。
  Widget _buildSoundChips(NightTheme theme) {
    final tracksAsync = ref.watch(audioTracksProvider);
    return tracksAsync.when(
      loading: () => const SizedBox(
        height: 32,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => Wrap(
        spacing: AppSpacing.s6,
        runSpacing: AppSpacing.s6,
        children: [
          _soundChip(
            label: '无',
            selected: _soundKey == null,
            onTap: () {
              _dismissKeyboard();
              setState(() => _soundKey = null);
            },
            theme: theme,
          ),
        ],
      ),
      data: (tracks) => Wrap(
        spacing: AppSpacing.s6,
        runSpacing: AppSpacing.s6,
        children: [
          _soundChip(
            label: '无',
            selected: _soundKey == null,
            onTap: () {
              _dismissKeyboard();
              setState(() => _soundKey = null);
            },
            theme: theme,
          ),
          ...tracks.map((track) => _soundChip(
                label: track.name,
                selected: _soundKey == track.key,
                onTap: () {
                  _dismissKeyboard();
                  setState(() => _soundKey = track.key);
                },
                theme: theme,
              )),
        ],
      ),
    );
  }

  Future<void> _save() async {
    _dismissKeyboard();
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('心情名字不能为空。');
      return;
    }
    try {
      final description = _descriptionController.text.trim();
      if (widget.existing == null) {
        await ref
            .read(emotionsProvider.notifier)
            .addCustom(name, description: description, soundKey: _soundKey);
      } else {
        await ref.read(emotionsProvider.notifier).save(
              existing: widget.existing!,
              name: name,
              color: _color,
              description: description,
              soundKey: _soundKey,
              clearSound: _soundKey == null,
            );
      }
      if (mounted) Navigator.of(context).pop();
    } on DuplicateEmotionNameException {
      _showMessage('这个名字已经存在啦。');
    } catch (_) {
      _showMessage('保存失败，请稍后再试。');
    }
  }

  void _close() {
    _dismissKeyboard();
    Navigator.of(context).pop();
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Widget _soundChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required NightTheme theme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12, vertical: AppSpacing.s6),
        decoration: BoxDecoration(
          color: selected
              ? theme.accent.withValues(alpha: theme.isNight ? .20 : .12)
              : theme.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? theme.accent : theme.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(label,
            style: AppText.chip.copyWith(
              color: selected ? theme.accent : theme.foregroundMuted,
            )),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ));
  }
}
