import 'island_status.dart';

class Island {
  const Island({
    required this.name,
    required this.status,
    required this.fragmentCount,
    required this.description,
  });

  final String name;
  final IslandStatus status;
  final int fragmentCount;
  final String description;
}
