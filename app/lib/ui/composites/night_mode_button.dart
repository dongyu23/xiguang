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

  AudioPlayer? _player;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _ensurePlayer() async {
    if (_player != null) return;
    _player = AudioPlayer();
    await _player!.setAsset(_switchSoundAsset);
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
          _playSwitchSound();
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

  void _playSwitchSound() {
    unawaited(_playSwitchSoundAsync());
  }

  Future<void> _playSwitchSoundAsync() async {
    try {
      await _ensurePlayer();
      final player = _player;
      if (player == null) return;
      await player.stop();
      await player.seek(Duration.zero);
      await player.play();
    } catch (_) {}
  }
}
