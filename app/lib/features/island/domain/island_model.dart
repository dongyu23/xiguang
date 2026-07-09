class IslandModel {
  const IslandModel({
    required this.name,
    this.islandId = 0,
    required this.status,
    required this.fragmentCount,
    required this.description,
    this.manual = false,
  });

  final String name;
  final int islandId;
  final String status;
  final int fragmentCount;
  final String description;
  final bool manual;
}
