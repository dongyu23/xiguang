import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../app/providers.dart';
import '../../design/tokens/colors.dart';

class NightModeButton extends ConsumerStatefulWidget {
  const NightModeButton({super.key});

  @override
  ConsumerState<NightModeButton> createState() => _NightModeButtonState();
}

class _NightModeButtonState extends ConsumerState<NightModeButton> {
  static const _switchSoundAsset =
      'assets/audio/DayNight mode switch sound.m4a';

  late final AudioPlayer _player;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    unawaited(_player.setAsset(_switchSoundAsset));
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nightMode = ref.watch(nightModeProvider);
    return Material(
      color: (nightMode ? AppColors.ink : AppColors.white)
          .withValues(alpha: nightMode ? .92 : .86),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: nightMode ? '切回白天' : '夜间轻开',
        onPressed: () {
          ref.read(nightModeProvider.notifier).state = !nightMode;
          unawaited(_playSwitchSound());
        },
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        padding: EdgeInsets.zero,
        iconSize: 19,
        visualDensity: VisualDensity.compact,
        icon: Icon(
          nightMode ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
        ),
        color: nightMode ? AppColors.emotionHappy : AppColors.ink,
      ),
    );
  }

  Future<void> _playSwitchSound() async {
    try {
      await _player.stop();
      await _player.seek(Duration.zero);
      await _player.play();
    } catch (_) {}
  }
}
