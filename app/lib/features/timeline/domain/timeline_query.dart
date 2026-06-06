class TimelineQuery {
  const TimelineQuery({
    this.emotion,
    this.mediaType,
    this.cursor,
    this.limit = 50,
  });

  final String? emotion;
  final String? mediaType;
  final String? cursor;
  final int limit;
}
