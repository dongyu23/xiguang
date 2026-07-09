import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xiguang/ui/primitives/overlay_snackbar.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/colors.dart';
import '../../../../design/tokens/radius.dart';
import '../../../../design/tokens/shadows.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../ui/primitives/night_background.dart';
import '../../../../ui/primitives/page_back_button.dart';
import '../../../../ui/spaces/space_canvas.dart';

class IslandCreatePage extends ConsumerStatefulWidget {
  const IslandCreatePage({super.key});

  @override
  ConsumerState<IslandCreatePage> createState() => _IslandCreatePageState();
}

class _IslandCreatePageState extends ConsumerState<IslandCreatePage> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _creating = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_syncNameState);
  }

  @override
  void dispose() {
    _nameController.removeListener(_syncNameState);
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _syncNameState() {
    if (!mounted) return;
    setState(() {
      if (_notice != null && _nameController.text.trim().isNotEmpty) {
        _notice = null;
      }
    });
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _notice = '先给这座岛取一个名字。');
      return;
    }
    setState(() {
      _creating = true;
      _notice = null;
    });
    try {
      final island = await ref.read(islandRepositoryProvider).createIsland(
            name,
            _descController.text.trim(),
          );
      ref.invalidate(islandsProvider);
      if (mounted) {
        final routeId =
            island.islandId > 0 ? '${island.islandId}' : island.name;
        context.push('/islands/${Uri.encodeComponent(routeId)}');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _notice = '小岛暂时没有建起来，请检查后端连接后再试。');
        showOverlaySnackBar(
          context,
          const SnackBar(content: Text('创建小岛失败，请稍后再试。')),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nightMode = ref.watch(nightModeProvider);
    final canCreate = _nameController.text.trim().isNotEmpty && !_creating;
    return Stack(children: [
      const Positioned.fill(child: NightBackgroundPlaceholder()),
      const Positioned.fill(child: AtmosphereBackground()),
      Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(22, 12, 22,
                64 + 10 + MediaQuery.paddingOf(context).bottom + 30),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _IslandPageHeader(title: '新建小岛', nightMode: nightMode),
                    const SizedBox(height: AppSpacing.s18),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s18),
                      decoration: nightMode
                          ? nightDecoration()
                          : softDecoration(AppColors.white),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ISLAND',
                              style:
                                  AppText.onNight(AppText.eyebrow, nightMode)),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '给这座岛取一个名字，它会慢慢长大。',
                            style: AppText.onNight(AppText.body, nightMode),
                          ),
                          const SizedBox(height: AppSpacing.s20),
                          TextField(
                            controller: _nameController,
                            autofocus: false,
                            style: AppText.onNight(AppText.body, nightMode),
                            decoration: _fieldDecoration(
                              label: '岛名',
                              hint: '比如：午夜咖啡馆',
                              nightMode: nightMode,
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: AppSpacing.s14),
                          TextField(
                            controller: _descController,
                            maxLines: 4,
                            style: AppText.onNight(AppText.body, nightMode),
                            decoration: _fieldDecoration(
                              label: '描述（可选）',
                              hint: '这座岛是什么样的...',
                              nightMode: nightMode,
                            ),
                          ),
                          if (_notice != null) ...[
                            const SizedBox(height: AppSpacing.s12),
                            Text(
                              _notice!,
                              style: AppText.caption
                                  .copyWith(color: AppColors.sunsetCoral),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.s22),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: canCreate ? _create : null,
                              icon: _creating
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.add_rounded),
                              label: Text(_creating ? '创建中...' : '创建小岛'),
                            ),
                          ),
                        ],
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

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required bool nightMode,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: AppText.onNight(AppText.caption, nightMode),
      hintStyle: AppText.onNight(AppText.placeholder, nightMode),
      filled: true,
      fillColor: nightMode
          ? AppColors.white.withValues(alpha: .08)
          : AppColors.paper.withValues(alpha: .56),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s14, vertical: AppSpacing.s14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(
          color: nightMode
              ? AppColors.white.withValues(alpha: .16)
              : AppColors.line.withValues(alpha: .78),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.teaGreen),
      ),
    );
  }
}

class _IslandPageHeader extends StatelessWidget {
  const _IslandPageHeader({required this.title, required this.nightMode});

  final String title;
  final bool nightMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PageBackButton(
          onTap: () => context.pop(),
          nightMode: nightMode,
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Text(
            title,
            style: AppText.onNight(AppText.titleLarge, nightMode),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
