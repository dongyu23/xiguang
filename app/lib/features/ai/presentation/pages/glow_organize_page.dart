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
  String _mode = 'name';
  bool _loading = false;
  String? _result;

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
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: softDecoration(AppColors.white),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('STAR KEEPER', style: AppText.eyebrow),
                      const SizedBox(height: 8),
                      Text('只在你主动触发时，给一点候选。', style: AppText.body),
                      const SizedBox(height: 16),
                      SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: 'name', label: Text('命名')),
                          ButtonSegment(value: 'weave', label: Text('织线')),
                          ButtonSegment(value: 'quiet', label: Text('不解释')),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (values) =>
                            setState(() => _mode = values.first),
                      ),
                      const SizedBox(height: 16),
                      GlowButton(
                        label: _loading ? '正在轻轻整理' : '请求柔光整理',
                        icon: Icons.auto_awesome_outlined,
                        onPressed: _loading ? null : _requestGlow,
                      ),
                      if (_result != null) ...[
                        const SizedBox(height: 16),
                        Text(_result!, style: AppText.body),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Future<void> _requestGlow() async {
    setState(() {
      _loading = true;
      _result = null;
    });
    try {
      final response = await ref.read(aiRepositoryProvider).glowSummary(
            AIRequest(mode: _mode, context: 'manual'),
          );
      setState(() => _result = response.summary ?? '请求已送达。');
    } catch (_) {
      setState(() => _result = '柔光整理暂时不可用，但不会影响捕光和回看。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
