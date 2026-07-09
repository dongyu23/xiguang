import 'package:freezed_annotation/freezed_annotation.dart';

part 'oplog.freezed.dart';
part 'oplog.g.dart';

/// 同步操作日志
@freezed
class OpLog with _$OpLog {
  // Freezed forwards this factory annotation to json_serializable.
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory OpLog({
    required String clientOpId,
    required String entityType,
    required String opType,
    required String entityPublicId,
    @Default({}) Map<String, dynamic> payload,
    @Default(0) int clientSeq,
    @Default(0) int baseServerVersion,
  }) = _OpLog;

  factory OpLog.fromJson(Map<String, dynamic> json) => _$OpLogFromJson(json);
}
