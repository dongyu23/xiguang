import 'package:flutter_test/flutter_test.dart';
import 'package:xiguang/features/sync/domain/oplog.dart';
import 'package:xiguang/features/sync/domain/sync_status.dart';

void main() {
  group('OpLog (freezed)', () {
    test('creates with required fields', () {
      final op = OpLog(
        clientOpId: 'test-op-1',
        entityType: 'fragment',
        opType: 'INSERT',
        entityPublicId: 'abc-123',
        payload: {'content_text': 'hello'},
      );
      expect(op.clientOpId, 'test-op-1');
      expect(op.entityType, 'fragment');
      expect(op.opType, 'INSERT');
      expect(op.clientSeq, 0);
      expect(op.baseServerVersion, 0);
    });

    test('toJson uses snake_case keys', () {
      final op = OpLog(
        clientOpId: 'test-op-1',
        entityType: 'fragment',
        opType: 'INSERT',
        entityPublicId: 'abc-123',
        payload: const {'key': 'value'},
        clientSeq: 5,
        baseServerVersion: 10,
      );
      final json = op.toJson();
      expect(json['client_op_id'], 'test-op-1');
      expect(json['entity_type'], 'fragment');
      expect(json['op_type'], 'INSERT');
      expect(json['entity_public_id'], 'abc-123');
      expect(json['client_seq'], 5);
      expect(json['base_server_version'], 10);
    });

    test('fromJson parses snake_case keys', () {
      final json = {
        'client_op_id': 'test-op-2',
        'entity_type': 'tag',
        'op_type': 'UPDATE',
        'entity_public_id': 'def-456',
        'payload': {'name': 'new-tag'},
        'client_seq': 3,
        'base_server_version': 7,
      };
      final op = OpLog.fromJson(json);
      expect(op.clientOpId, 'test-op-2');
      expect(op.entityType, 'tag');
      expect(op.opType, 'UPDATE');
      expect(op.entityPublicId, 'def-456');
      expect(op.payload, {'name': 'new-tag'});
      expect(op.clientSeq, 3);
      expect(op.baseServerVersion, 7);
    });

    test('fromJson/toJson roundtrip', () {
      final original = OpLog(
        clientOpId: 'roundtrip-test',
        entityType: 'fragment',
        opType: 'DELETE',
        entityPublicId: 'ghi-789',
        payload: const {'id': 42},
        clientSeq: 1,
        baseServerVersion: 5,
      );
      final json = original.toJson();
      final restored = OpLog.fromJson(json);
      expect(restored, equals(original));
    });

    test('equality works', () {
      final a = OpLog(
        clientOpId: 'eq-test',
        entityType: 'fragment',
        opType: 'INSERT',
        entityPublicId: 'abc',
      );
      final b = OpLog(
        clientOpId: 'eq-test',
        entityType: 'fragment',
        opType: 'INSERT',
        entityPublicId: 'abc',
      );
      expect(a, equals(b));
    });
  });

  group('SyncStatus (freezed)', () {
    test('creates with defaults', () {
      const status = SyncStatus(
        lastServerRev: 0,
        pendingCount: 0,
        isSyncing: false,
      );
      expect(status.connected, true);
      expect(status.error, isNull);
      expect(status.lastSyncAt, isNull);
    });

    test('copyWith works', () {
      const status = SyncStatus(
        lastServerRev: 10,
        pendingCount: 3,
        isSyncing: false,
      );
      final updated = status.copyWith(
        lastServerRev: 15,
        isSyncing: true,
      );
      expect(updated.lastServerRev, 15);
      expect(updated.isSyncing, true);
      expect(updated.pendingCount, 3); // unchanged
      expect(updated.connected, true); // unchanged
    });

    test('copyWith can set error to null', () {
      const status = SyncStatus(
        lastServerRev: 0,
        pendingCount: 0,
        isSyncing: false,
        error: 'some error',
      );
      final cleared = status.copyWith(error: null);
      // freezed treats null as "don't change" for nullable fields
      // but explicit null should clear it
      expect(cleared.error, isNull);
    });

    test('equality works', () {
      const a = SyncStatus(
        lastServerRev: 5,
        pendingCount: 2,
        isSyncing: false,
        lastSyncAt: null,
      );
      const b = SyncStatus(
        lastServerRev: 5,
        pendingCount: 2,
        isSyncing: false,
        lastSyncAt: null,
      );
      expect(a, equals(b));
    });
  });
}
