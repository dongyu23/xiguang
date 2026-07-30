import 'package:flutter/material.dart';

import '../../../../design/tokens/colors.dart';

/// 为自定义关系类型名分配一个稳定的莫兰迪色（与 emotion_color 同算法）。
Color autoColorForRelationTypeName(String name) {
  if (name.isEmpty) return AppColors.emotionUnclear;
  var hash = 0;
  for (final codeUnit in name.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7FFFFFFF;
  }
  const palette = <int>[
    0xFFB8C5B2,
    0xFFC9B8D4,
    0xFFD4C5B8,
    0xFFB8C9D4,
    0xFFD4B8C0,
    0xFFC0D4B8,
    0xFFB8D4C9,
    0xFFD4CBB8,
  ];
  return Color(palette[hash % palette.length]);
}

/// iconKey -> IconData 映射。关系类型只存 key 字符串，避免在 DB 里存 code point。
/// 新增默认类型时在此登记图标；自定义类型若用了未登记的 key，回退到回声图标。
IconData iconForRelationType(String iconKey) {
  switch (iconKey) {
    case 'auto_awesome_rounded':
      return Icons.auto_awesome_rounded;
    case 'edit_note_rounded':
      return Icons.edit_note_rounded;
    case 'trip_origin_rounded':
      return Icons.trip_origin_rounded;
    case 'grain_rounded':
      return Icons.grain_rounded;
    case 'favorite_border_rounded':
      return Icons.favorite_border_rounded;
    case 'waves_rounded':
      return Icons.waves_rounded;
    case 'circle_rounded':
      return Icons.circle_rounded;
    case 'bolt_rounded':
      return Icons.bolt_rounded;
    case 'sync_rounded':
      return Icons.sync_rounded;
    case 'route_rounded':
      return Icons.route_rounded;
    default:
      return Icons.auto_awesome_rounded;
  }
}

/// 管理页可选图标清单（供编辑表单的图标选择器使用）。
const relationTypeIconOptions = <(String, IconData)>[
  ('auto_awesome_rounded', Icons.auto_awesome_rounded),
  ('edit_note_rounded', Icons.edit_note_rounded),
  ('trip_origin_rounded', Icons.trip_origin_rounded),
  ('grain_rounded', Icons.grain_rounded),
  ('favorite_border_rounded', Icons.favorite_border_rounded),
  ('waves_rounded', Icons.waves_rounded),
  ('circle_rounded', Icons.circle_rounded),
  ('bolt_rounded', Icons.bolt_rounded),
  ('sync_rounded', Icons.sync_rounded),
  ('route_rounded', Icons.route_rounded),
];
