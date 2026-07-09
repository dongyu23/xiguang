import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xiguang/ui/primitives/overlay_snackbar.dart';

import '../../application/island_create_controller.dart';
import '../../../../design/themes/extensions/night_theme.dart';
import '../../../../design/tokens/typography.dart';
import '../../../../design/tokens/spacing.dart';
import '../../../../ui/composites/xiguang_button.dart';
import '../../../../ui/composites/xiguang_card.dart';
import '../../../../ui/composites/xiguang_input.dart';
import '../../../../ui/composites/xiguang_page.dart';
import '../../../../ui/spaces/space_canvas.dart';

class IslandCreatePage extends ConsumerStatefulWidget {
  const IslandCreatePage({super.key});

  @override
  ConsumerState<IslandCreatePage> createState() => _IslandCreatePageState();
}

class _IslandCreatePageState extends ConsumerState<IslandCreatePage> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
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
      _notice = null;
    });
    try {
      final island =
          await ref.read(islandCreateControllerProvider.notifier).create(
                name: name,
                description: _descController.text.trim(),
              );
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(islandCreateControllerProvider);
    final canCreate =
        _nameController.text.trim().isNotEmpty && !createState.isCreating;
    return XiguangPage(
      backgroundLayer: const AtmosphereBackground(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s22,
        AppSpacing.s12,
        AppSpacing.s22,
        AppSpacing.pageBottomNav + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _IslandPageHeader(title: '新建小岛'),
          const SizedBox(height: AppSpacing.s18),
          XiguangCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ISLAND', style: AppText.eyebrow),
                const SizedBox(height: AppSpacing.sm),
                const Text('给这座岛取一个名字，它会慢慢长大。', style: AppText.body),
                const SizedBox(height: AppSpacing.s20),
                XiguangInput(
                  controller: _nameController,
                  label: '岛名',
                  hint: '比如：午夜咖啡馆',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: AppSpacing.s14),
                XiguangInput(
                  controller: _descController,
                  label: '描述（可选）',
                  hint: '这座岛是什么样的...',
                  maxLines: 4,
                ),
                if (_notice != null) ...[
                  const SizedBox(height: AppSpacing.s12),
                  Builder(builder: (context) {
                    return Text(
                      _notice!,
                      style: AppText.caption.copyWith(
                        color: NightTheme.of(context).danger,
                      ),
                    );
                  }),
                ],
                const SizedBox(height: AppSpacing.s22),
                XiguangButton(
                  label: createState.isCreating ? '创建中...' : '创建小岛',
                  leading: const Icon(Icons.add_rounded),
                  loading: createState.isCreating,
                  onPressed: canCreate ? _create : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IslandPageHeader extends StatelessWidget {
  const _IslandPageHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = NightTheme.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: '返回',
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_rounded, color: theme.foreground),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Text(
            title,
            style: AppText.titleLarge.copyWith(color: theme.foreground),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
