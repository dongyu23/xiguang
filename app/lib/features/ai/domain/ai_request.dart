class AIScope {
  const AIScope.fragments(this.fragmentIds)
      : type = 'fragments',
        islandId = null,
        rangeDays = null;
  const AIScope.island(this.islandId)
      : type = 'island',
        fragmentIds = const [],
        rangeDays = null;
  const AIScope.range(this.rangeDays)
      : type = 'range',
        fragmentIds = const [],
        islandId = null;

  final String type;
  final List<int> fragmentIds;
  final int? islandId;
  final int? rangeDays;

  Map<String, dynamic> toJson() => {
        'type': type,
        if (fragmentIds.isNotEmpty) 'fragment_ids': fragmentIds,
        if (islandId != null) 'island_id': islandId,
        if (rangeDays != null) 'range_days': rangeDays,
      };

  String get label => switch (type) {
        'fragments' => '选中的 ${fragmentIds.length} 束光',
        'island' => '当前这座岛',
        _ => '最近 $rangeDays 天',
      };
}

class AIRequest {
  const AIRequest(
      {required this.mode, this.fragmentIds = const [], this.context});
  final String mode;
  final List<int> fragmentIds;
  final String? context;
}
