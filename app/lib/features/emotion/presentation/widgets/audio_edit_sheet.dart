import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/motion.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../ui/composites/xiguang_bottom_sheet.dart';
import '../../../../ui/composites/xiguang_button.dart';
import '../../../../ui/composites/xiguang_input.dart';
import '../../application/audio_library_controller.dart';

/// 新增背景音乐 sheet - 选择音频文件 + 命名，保存到音频库。
class AudioEditSheet extends ConsumerStatefulWidget {
  const AudioEditSheet({super.key});

  @override
  ConsumerState<AudioEditSheet> createState() => _AudioEditSheetState();
}

class _AudioEditSheetState extends ConsumerState<AudioEditSheet> {
  final TextEditingController _nameController = TextEditingController();
  String? _pickedPath;
  String? _pickedFileName;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final fileName = result.files.single.name;
    setState(() {
      _pickedPath = path;
      _pickedFileName = fileName;
      if (_nameController.text.trim().isEmpty) {
        final dot = fileName.lastIndexOf('.');
        _nameController.text = dot > 0 ? fileName.substring(0, dot) : fileName;
      }
    });
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_pickedPath == null) {
      _showMessage('请先选择一个音频文件。');
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('给这段背景音乐取个名字吧。');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(audioTracksProvider.notifier).addFromFile(
            sourcePath: _pickedPath!,
            displayName: name,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _showMessage('保存失败，请稍后再试。');
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final maxSheetHeight = mediaQuery.size.height -
        bottomInset -
        mediaQuery.padding.top -
        AppSpacing.md;
    return AnimatedPadding(
      duration: AppMotion.fast,
      curve: AppMotion.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: XiguangBottomSheet(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text('新增背景音乐',
                        style: AppText.titleLarge
                            .copyWith(color: theme.foreground)),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    icon:
                        Icon(Icons.close_rounded, color: theme.foregroundMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ]),
                const SizedBox(height: AppSpacing.md),
                Flexible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        XiguangInput(
                          controller: _nameController,
                          maxLength: 12,
                          autofocus: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          label: '音乐名字',
                          hint: '例如：雨夜',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text('音频文件',
                            style: AppText.caption
                                .copyWith(color: theme.foregroundMuted)),
                        const SizedBox(height: AppSpacing.s6),
                        _FilePickerRow(
                          fileName: _pickedFileName,
                          onPick: _pickFile,
                          theme: theme,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s14),
                XiguangButton(
                  label: _saving ? '保存中…' : '保存',
                  loading: _saving,
                  leading: const Icon(Icons.check_rounded, size: 18),
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilePickerRow extends StatelessWidget {
  const _FilePickerRow({
    required this.fileName,
    required this.onPick,
    required this.theme,
  });

  final String? fileName;
  final VoidCallback onPick;
  final NightTheme theme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12, vertical: AppSpacing.s10),
        decoration: BoxDecoration(
          color: theme.surface.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: theme.border),
        ),
        child: Row(children: [
          Icon(Icons.audio_file_outlined,
              size: 20, color: theme.foregroundMuted),
          const SizedBox(width: AppSpacing.s6),
          Expanded(
            child: Text(
              fileName ?? '点击选择音频文件',
              style: AppText.body.copyWith(
                color:
                    fileName == null ? theme.foregroundMuted : theme.foreground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 20, color: theme.foregroundMuted),
        ]),
      ),
    );
  }
}
