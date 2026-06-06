/// Island 实体 — "主题岛"
class Island {
  const Island(
      {required this.id,
      required this.publicId,
      required this.userId,
      required this.name,
      required this.status,
      required this.fragmentCount,
      this.description = ''});

  final int id;
  final String publicId;
  final int userId;
  final String name;
  final String status; // star_point/growing/formed/dormant/relit
  final int fragmentCount;
  final String description;
}
