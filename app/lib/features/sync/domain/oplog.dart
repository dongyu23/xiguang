class OpLog {
  const OpLog({
    required this.clientOpId,
    required this.entityType,
    required this.opType,
    required this.entityPublicId,
    required this.payload,
    required this.clientSeq,
    required this.baseServerVersion,
  });

  final String clientOpId;
  final String entityType;
  final String opType;
  final String entityPublicId;
  final Map<String, dynamic> payload;
  final int clientSeq;
  final int baseServerVersion;

  Map<String, dynamic> toJson() => {
        'client_op_id': clientOpId,
        'entity_type': entityType,
        'op_type': opType,
        'entity_public_id': entityPublicId,
        'payload': payload,
        'client_seq': clientSeq,
        'base_server_version': baseServerVersion,
      };

  factory OpLog.fromJson(Map<String, dynamic> json) {
    return OpLog(
      clientOpId: json['client_op_id'] as String? ?? '',
      entityType: json['entity_type'] as String? ?? '',
      opType: json['op_type'] as String? ?? '',
      entityPublicId: json['entity_public_id'] as String? ?? '',
      payload: (json['payload'] as Map<String, dynamic>?) ?? const {},
      clientSeq: (json['client_seq'] as num?)?.toInt() ?? 0,
      baseServerVersion: (json['base_server_version'] as num?)?.toInt() ?? 0,
    );
  }
}
