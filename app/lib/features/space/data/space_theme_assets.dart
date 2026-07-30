import '../domain/space_theme.dart';

const builtinSpaceThemes = <SpaceTheme>[
  SpaceTheme(
    id: 'morning_mist',
    name: '晨雾',
    primaryColorHex: '#72A58F',
    description: '一层轻柔的微光。',
    selected: true,
  ),
  SpaceTheme(
    id: 'starry',
    name: '静夜星点',
    primaryColorHex: '#61748F',
    description: '把星点留在安静的深蓝里。',
  ),
  SpaceTheme(
    id: 'ocean',
    name: '潮声',
    primaryColorHex: '#7096A6',
    description: '低缓的海面托住正在流动的光。',
    requiredTier: 'starlight',
    locked: true,
  ),
  SpaceTheme(
    id: 'island',
    name: '雾中小岛',
    primaryColorHex: '#8B9B78',
    description: '让反复出现的主题慢慢靠岸。',
    requiredTier: 'starlight',
    locked: true,
  ),
];
