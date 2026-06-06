import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../ui/spaces/island_space.dart';
import '../../../../ui/spaces/ocean_space.dart';
import '../../../../ui/spaces/starry_space.dart';
import '../../domain/space_theme.dart';

class SpacePage extends ConsumerStatefulWidget {
  const SpacePage({super.key});

  @override
  ConsumerState<SpacePage> createState() => _SpacePageState();
}

class _SpacePageState extends ConsumerState<SpacePage> {
  SpaceThemeValue _theme = SpaceThemeValue.starry;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    ref.read(spaceRepositoryProvider).currentTheme().then((theme) {
      if (mounted) setState(() => _theme = theme);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: _background),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              SegmentedButton<SpaceThemeValue>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: .18),
                  foregroundColor: Colors.white,
                  selectedBackgroundColor: Colors.white.withValues(alpha: .82),
                  selectedForegroundColor: const Color(0xFF233332),
                ),
                segments: const [
                  ButtonSegment(
                      value: SpaceThemeValue.starry, label: Text('星')),
                  ButtonSegment(value: SpaceThemeValue.ocean, label: Text('海')),
                  ButtonSegment(
                      value: SpaceThemeValue.island, label: Text('屿')),
                ],
                selected: {_theme},
                onSelectionChanged: (values) {
                  final next = values.first;
                  setState(() => _theme = next);
                  ref.read(spaceRepositoryProvider).saveTheme(next);
                },
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget get _background {
    return switch (_theme) {
      SpaceThemeValue.ocean => const OceanSpace(waveLayers: 5),
      SpaceThemeValue.island => const IslandSpace(),
      _ => const StarrySpace(starCount: 40),
    };
  }
}
