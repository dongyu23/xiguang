import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../design/tokens/typography.dart';
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

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _creating = true);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('创建小岛失败，请稍后再试。')),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(child: AtmosphereBackground()),
      Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('新建小岛'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '给这座岛取一个名字，它会慢慢长大。',
                      style: AppText.body,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: '岛名',
                        hintText: '比如：午夜咖啡馆',
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '描述（可选）',
                        hintText: '这座岛是什么样的...',
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _creating ? null : _create,
                        icon: _creating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.add_rounded),
                        label: Text(_creating ? '创建中...' : '创建小岛'),
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
}
