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
}
