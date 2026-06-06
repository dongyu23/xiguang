enum IslandStatus {
  starPoint,
  growing,
  formed;

  String get label {
    return switch (this) {
      IslandStatus.starPoint => '星点',
      IslandStatus.growing => '生长中',
      IslandStatus.formed => '已成岛',
    };
  }
}
