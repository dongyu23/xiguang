import '../domain/noise_audio.dart';

const builtinNoiseAudios = [
  NoiseAudio(
    id: 'rain',
    name: '雨声',
    icon: 'rain',
    audioFile: 'assets/audio/rain.mp3',
    category: 'nature',
  ),
  NoiseAudio(
    id: 'pages',
    name: '翻书声',
    icon: 'pages',
    audioFile: '',
    category: 'room',
  ),
  NoiseAudio(
    id: 'wind',
    name: '风声',
    icon: 'wind',
    audioFile: '',
    category: 'nature',
    requiredTier: 'starlight',
    locked: true,
  ),
  NoiseAudio(
    id: 'heartbeat',
    name: '心跳声',
    icon: 'heartbeat',
    audioFile: '',
    category: 'body',
    requiredTier: 'starlight',
    locked: true,
  ),
];
