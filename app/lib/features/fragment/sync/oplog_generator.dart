class OpLogGenerator {
  int _seq = 0;

  Map<String, dynamic> insertFragment(
      String publicId, Map<String, dynamic> payload) {
    _seq += 1;
    return {
      'client_op_id': 'fragment-insert-$_seq',
      'entity_type': 'fragment',
      'op_type': 'INSERT',
      'entity_public_id': publicId,
      'payload': payload,
      'client_seq': _seq,
      'base_server_version': 0,
    };
  }
}
