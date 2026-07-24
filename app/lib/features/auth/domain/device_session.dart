class DeviceSession {
  const DeviceSession({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.isCurrent,
    required this.createdAt,
    required this.expiresAt,
  });

  final int id;
  final String deviceId;
  final String deviceName;
  final bool isCurrent;
  final DateTime createdAt;
  final DateTime expiresAt;
}
